# 1. Create VPC (Custom Mode)
resource "google_compute_network" "vpc" {
  name                    = var.vpc_name
  auto_create_subnetworks = false # Critical: disable auto subnet creation
  routing_mode            = "REGIONAL"
}

# 2. Create Subnets (3 Public + 3 Private = 6 total)
# In GCP, subnets are regional, but we create 6 to match AWS structure
resource "google_compute_subnetwork" "subnets" {
  count         = length(var.subnet_cidrs)
  name          = "${var.vpc_name}-subnet-${count.index + 1}"
  ip_cidr_range = var.subnet_cidrs[count.index]
  region        = var.region
  network       = google_compute_network.vpc.id
}

# 3. Create Route (Allow Internet Access for Public Subnets)
# Target: 0.0.0.0/0 -> Default Internet Gateway
resource "google_compute_route" "public_internet_access" {
  name             = "${var.vpc_name}-public-route"
  dest_range       = "0.0.0.0/0"
  network          = google_compute_network.vpc.id
  next_hop_gateway = "default-internet-gateway"
  priority         = 1000
}

# 4. Firewall Rule: Allow Web/SSH Traffic
resource "google_compute_firewall" "allow_web" {
  name    = "${var.vpc_name}-allow-web"
  network = google_compute_network.vpc.id

  allow {
    protocol = "tcp"
    ports    = ["80", "443", "22", "8080"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["webapp"] # VMs with this tag will allow traffic
}

# 5. Firewall Rule: Deny All Other Traffic (Explicit)
resource "google_compute_firewall" "deny_all" {
  name     = "${var.vpc_name}-deny-all"
  network  = google_compute_network.vpc.id
  priority = 65534 # Low priority (higher number = lower priority)

  deny {
    protocol = "all"
  }

  source_ranges = ["0.0.0.0/0"]
}

# ============================================================
# Cloud SQL Resources
# ============================================================

# 6a. Enable private services access for Cloud SQL
resource "google_compute_global_address" "private_ip_range" {
  name          = "${var.vpc_name}-private-ip-range"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.vpc.id
}

resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = google_compute_network.vpc.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_range.name]
}

# 6b. Cloud SQL MySQL Instance
resource "google_sql_database_instance" "webapp" {
  name             = "csye6225-db"
  database_version = "MYSQL_8_0"
  region           = var.region

  depends_on = [google_service_networking_connection.private_vpc_connection]

  deletion_protection = false

  settings {
    tier              = var.db_tier
    availability_type = "ZONAL"
    disk_size         = 20
    disk_type         = "PD_SSD"

    ip_configuration {
      ipv4_enabled    = false
      private_network = google_compute_network.vpc.id
    }
  }
}

# 6c. Cloud SQL Database
resource "google_sql_database" "webapp" {
  name     = "csye6225"
  instance = google_sql_database_instance.webapp.name
}

# 6d. Cloud SQL User
resource "google_sql_user" "webapp" {
  name     = "csye6225"
  instance = google_sql_database_instance.webapp.name
  password = var.db_password
}

# 6e. Data source to find the latest custom image
data "google_compute_image" "webapp" {
  family  = "csye6225-webapp"
  project = "weihong-dev" # Dev project - where images are built
}

# 7. Compute Engine Instance
resource "google_compute_instance" "webapp" {
  name         = "${var.vpc_name}-webapp-instance"
  machine_type = var.machine_type
  zone         = var.instance_zone

  # Boot disk configuration
  boot_disk {
    auto_delete = true

    initialize_params {
      image = data.google_compute_image.webapp.self_link
      size  = 25
      type  = "pd-balanced"
    }
  }

  # Network configuration
  network_interface {
    subnetwork = google_compute_subnetwork.subnets[0].id

    # Assign external IP
    access_config {
      // Ephemeral public IP
    }
  }

  # Network tags for firewall rules
  tags = ["webapp"]

  # Startup script to inject database credentials
  metadata = {
    enable-oslogin = "FALSE"
    startup-script = <<-EOF
      #!/bin/bash
      echo "SPRING_DATASOURCE_URL=jdbc:mysql://${google_sql_database_instance.webapp.private_ip_address}:3306/csye6225?useSSL=false&serverTimezone=UTC&allowPublicKeyRetrieval=true" >> /etc/environment
      echo "SPRING_DATASOURCE_USERNAME=csye6225" >> /etc/environment
      echo "SPRING_DATASOURCE_PASSWORD=${var.db_password}" >> /etc/environment
      source /etc/environment
      systemctl restart webapp
    EOF
  }

  # Disable deletion protection
  deletion_protection = false

  # Service account (use default compute service account or create dedicated one)
  service_account {
    scopes = ["cloud-platform"]
  }
}
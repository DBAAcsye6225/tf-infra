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

# 6. Data source to find the latest custom image
data "google_compute_image" "webapp" {
  family  = "csye6225-webapp"
  project = var.project_id
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

  # Metadata (optional)
  metadata = {
    enable-oslogin = "FALSE"
  }

  # Disable deletion protection
  deletion_protection = false

  # Service account (use default compute service account or create dedicated one)
  service_account {
    scopes = ["cloud-platform"]
  }
}
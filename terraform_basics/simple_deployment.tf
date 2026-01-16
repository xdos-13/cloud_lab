
provider "google" {
  credentials = "${file("loader.json")}"
  project     = var.project
  region      = var.region
  zone        = var.zone
}



resource "google_compute_instance" "vm_instance" {

  count        = 1
  name         = "${var.instance-name}-${count.index}"

  machine_type = "e2-medium"

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
    }
  }

  network_interface {
    # A default network is created for all GCP projects
    network       = "default"
    access_config {
    }
  }

  metadata_startup_script = file("setup_loadgen.sh")

  tags = ["loadgen", "http-server"]
}

output "ip" {
  value       = google_compute_instance.vm_instance[0].network_interface.0.access_config.0.nat_ip
  description = "External IP of load generator VM"
}

output "ssh_command" {
  value       = "gcloud compute ssh ${var.instance-name}-0 --zone=${var.zone}"
  description = "Command to SSH into the load generator"
}

output "test_guide" {
  value = <<-EOT
    
    ===================================================================
    PERFORMANCE TESTING GUIDE
    ===================================================================
    
    1. Wait 5-7 minutes for VM setup to complete
    
    2. Get your frontend IP:
       kubectl get service frontend-external
    
    3. SSH into load generator:
       ${self.triggers.ssh_cmd}
    
    4. PHASE 1 - Single Instance Tests (Baseline):
       /opt/loadgen-scripts/run_all_tests.sh <FRONTEND_IP>
       
       Monitor load generator CPU during tests:
       /opt/loadgen-scripts/monitor_loadgen.sh (in another terminal)
    
    5. PHASE 2 - Distributed Tests (High Load):
       Only run if single instance shows CPU saturation
       /opt/loadgen-scripts/run_high_load_tests.sh <FRONTEND_IP>
    
    6. Download results:
       mkdir -p ~/gke-performance-results
       gcloud compute scp --recurse ${var.instance-name}-0:/opt/locust-results/* ~/gke-performance-results/ --zone=${var.zone}
    
    7. Available helper scripts:
       - /opt/loadgen-scripts/list_results.sh
       - /opt/loadgen-scripts/monitor_loadgen.sh
       - /opt/loadgen-scripts/clean_results.sh
    
    ===================================================================
  EOT
}


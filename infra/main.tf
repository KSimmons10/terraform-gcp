#cloud storage bucket

resource "google_storage_bucket" "website" {
    provider = google
    name = "example-website-by-komari"
    location = "US"

}

#make new object public
resource "google_storage_object_access_control" "public_rule" {
    object = google_storage_bucket_object.static_site_src.name
    bucket = google_storage_bucket.website.name
    role = "READER"
    entity = "allUsers"  
}

#upload HTML Fille
resource "google_storage_bucket_object" "static_site_src" {
    name = "easy.html"
    source = "../website/easy.html"
    bucket = google_storage_bucket.website.name
}

#reserve statci external IP address
resource "google_compute_global_address" "website" {
    name = "website-lb-ip"
}

#get dns managed zone
data "google_dns_managed_zone" "dns_zone"{
    name = "dns-new-zone"
}

#add ip to dns
resource "google_dns_record_set" "website" {
    name= "K0mari.${data.google_dns_managed_zone.dns_zone.dns_name}"
    type= "A"
    ttl = 300
    managed_zone = data.google_dns_managed_zone.dns_zone.name
    rrdatas = [google_compute_global_address.website.address]
}

#add the bucket as a CDN backend
resource "google_compute_backend_bucket" "website-backend" {
    name = "website-bucket"
    bucket_name = google_storage_bucket.website.name
    description = "contains files needed for the website"
    enable_cdn = true 
}

#GCP URL Map
resource "google_compute_url_map" "website" {
    name = "website-url-map"
    default_service = google_compute_backend_bucket.website-backend.self_link
    host_rule {
        hosts = ["*"]
        path_matcher = "allpaths"
    }
    path_matcher {
      name = "allpaths"
      default_service = google_compute_backend_bucket.website-backend.self_link
    }
}

# gcp HTTP Proxy

resource "google_compute_target_http_proxy" "website" {
    name = "website-target-proxy"
    url_map = google_compute_url_map.website.self_link
}

#gcp forwarding rule
resource "google_compute_global_forwarding_rule" "default" {
    name = "website-forwarding-rule"
    load_balancing_scheme = "EXTERNAL"
    ip_address = google_compute_global_address.website.address
    ip_protocol = "TCP"
    port_range = "80"
    target = google_compute_target_http_proxy.website.self_link
}
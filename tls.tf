provider "acme" {
  server_url = "https://acme-staging-v02.api.letsencrypt.org/directory"
}

resource "tls_private_key" "private_key" {
  algorithm = "RSA"
}

resource "acme_registration" "reg" {
  account_key_pem = "${tls_private_key.private_key.private_key_pem}"
  email_address   = "andrei@chenchik.me"
}

resource "acme_certificate" "certificate" {
  account_key_pem           = "${acme_registration.reg.account_key_pem}"
  common_name               = "${var.dns-subdomain}.${var.dns-zone}"

  dns_challenge {
    provider = "gcloud"
    
    config = {
      GCE_PROJECT = "${var.project_id}"
      GCE_SERVICE_ACCOUNT = "${var.credentials}"
      }
  }
}

resource "kubernetes_ingress" "ingress" {
  count = local.node_count != 1 ? 0 : 1

  metadata {
    name = "container-ingress"

    annotations = {
      "ingress.gcp.kubernetes.io/pre-shared-cert" = acme_certificate.certificate[0].certificate_pem
    }
  }

  spec {
    rule {
      http {
        path {
          backend {
            service_name = kubernetes_service.proxy[0].metadata.0.name
            service_port = 80
          }
        }
      }
    }
  }
}

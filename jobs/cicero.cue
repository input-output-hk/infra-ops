package jobs

#ciceroRev: "daa46e9bbfb9bccfe8ceb69011d255b295970c7d"

job: {
	cicero: {
		type: "service"

		group: cicero: {
			restart: {
				attempts: 5
				delay:    "10s"
				interval: "1m"
				mode:     "delay"
			}

			reschedule: {
				delay:          "10s"
				delay_function: "exponential"
				max_delay:      "1m"
				unlimited:      true
			}

			network: {
				mode: "bridge"
				port: http: to: "8080"
			}

			service: [{
				name:         "cicero"
				address_mode: "auto"
				port:         "http"
				task:         "cicero"
				tags: [
					"cicero",
					"ingress",
					"traefik.enable=true",
					"traefik.http.routers.cicero.rule=Host(`cicero.infra.aws.iohkdev.io`)",
					"traefik.http.routers.cicero.entrypoints=https",
					"traefik.http.routers.cicero.tls=true",
				]
				check: [{
					type:     "tcp"
					port:     "http"
					interval: "10s"
					timeout:  "2s"
				}]
			}]

			task: cicero: {
				driver: "nix"

				vault: {
					policies: ["cicero"]
					change_mode: "restart"
				}

				resources: {
					memory: 1024
					cpu:    300
				}

				env: {
					DATABASE_URL:  "sqlite:db/database.sqlite3"
					NIX_CONFIG:    "experimental-features = nix-command flakes"
					SSL_CERT_FILE: "/current-profile/etc/ssl/certs/ca-bundle.crt"
					NOMAD_ADDR:    "https://nomad.infra.aws.iohkdev.io"
					VAULT_ADDR:    "https://vault.infra.aws.iohkdev.io"
				}

				config: [{
					packages: [
						"github:input-output-hk/cicero/\(#ciceroRev)#cicero",
						"github:input-output-hk/cicero/\(#ciceroRev)#cicero-evaluator-nix",
						"github:input-output-hk/cicero/\(#ciceroRev)#wfs",
						"github:nixos/nixpkgs/nixpkgs-unstable#nixUnstable",
						"github:nixos/nixpkgs/nixpkgs-unstable#bash",
						"github:nixos/nixpkgs/nixpkgs-unstable#coreutils",
						"github:nixos/nixpkgs/nixpkgs-unstable#shadow",
						"github:nixos/nixpkgs/nixpkgs-unstable#git",
						"github:nixos/nixpkgs/nixpkgs-unstable#cacert",
						"github:nixos/nixpkgs/nixpkgs-unstable#dbmate",
						"github:nixos/nixpkgs/nixpkgs-unstable#vault-bin",
					]

					command: ["/bin/bash", "/local/entrypoint.sh"]
				}]

				template: [{
					destination: "/local/entrypoint.sh"
					data: """
						set -exuo pipefail

						env

						mkdir -p /etc
						echo 'nixbld:x:30000:nixbld1' > /etc/group
						echo 'nixbld1:x:30001:30000:Nix build user 1:/current-profile/var/empty:/bin/nologin' > /etc/passwd
						echo 'nameserver 172.17.0.1' > /etc/resolv.conf
						nix-store --load-db < /registration

						git clone --quiet --depth 1 https://github.com/input-output-hk/cicero
						cd cicero
						dbmate up

						NOMAD_TOKEN="$(vault read -field secret_id nomad/creds/cicero)"
						export NOMAD_TOKEN

						exec /bin/cicero all --liftbridge-addr liftbridge.service.consul:9292
						"""
				}]
			}
		}
	}
}

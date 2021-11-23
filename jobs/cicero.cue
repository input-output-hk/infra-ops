package jobs

job: cicero: {
	#sha:            string
	#databaseUrl:    "postgres://cicero:@hydra.node.consul:5432/cicero?sslmode=disable"
	#ciceroFlake:    "github:input-output-hk/cicero/\(#sha)#cicero-entrypoint"
	#nomadAddr:      "https://nomad.infra.aws.iohkdev.io"
	#vaultAddr:      "https://vault.infra.aws.iohkdev.io"
	#liftbridgeAddr: "liftbridge.service.consul:9292"

	group: {
		cicero: {
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
				mode: "host"
				port: http: static: "8888"
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

				resources: {
					memory: 1024
					cpu:    300
				}

				vault: {
					policies: ["cicero"]
					change_mode: "restart"
				}

				env: {
					DATABASE_URL: #databaseUrl
					NOMAD_ADDR:   #nomadAddr
					VAULT_ADDR:   #vaultAddr
				}

				config: [{
					packages: [#ciceroFlake]
					command: [
						"/bin/entrypoint",
						"--liftbridge-addr", #liftbridgeAddr,
						"--listen", ":8888",
					]
				}]
			}
		}
	}
}

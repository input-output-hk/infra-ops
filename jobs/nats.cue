package jobs

job: nats: {
	group: nats: {
		network: {
			mode: "host"
			port: nats: static: "4222"
		}

		service: [{
			name:         "nats"
			address_mode: "auto"
			port:         "nats"
			tags: ["voter-0"]
			check: [{
				type:     "tcp"
				port:     "nats"
				interval: "10s"
				timeout:  "2s"
			}]
		}]

		task: nats: {
			driver: "nix"

			resources: {
				memory: 128
				cpu:    200
			}

			config: {
				packages: ["github:nixos/nixpkgs#nats-server"]
				command: [
					"/bin/nats-server",
					"--debug",
				]
			}
		}
	}
}

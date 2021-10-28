package jobs

import (
	"encoding/yaml"
)

job: liftbridge: {
	type: "service"

	update: {
		max_parallel:      1
		health_check:      "checks"
		min_healthy_time:  "10s"
		healthy_deadline:  "5m"
		progress_deadline: "10m"
		auto_revert:       true
		stagger:           "30s"
	}

	group: {
		#prototype: {
			#id:   number
			#seed: bool

			network: [{
				mode: "host"
				port: nats: static:       "4222"
				port: liftbridge: static: "9292"
			}]

			service: [{
				name:         "liftbridge"
				address_mode: "host"
				port:         "nats"
				task:         "liftbridge"
				tags: ["voter-\(#id)"]
				check: [{
					type:     "tcp"
					port:     "liftbridge"
					interval: "10s"
					timeout:  "2s"
				}]
			}, {
				name:         "liftbridge-nats"
				address_mode: "host"
				port:         "nats"
				task:         "liftbridge"
				tags: ["voter-\(#id)"]
				check: [{
					type:     "tcp"
					port:     "nats"
					interval: "10s"
					timeout:  "2s"
				}]
			}]

			task: liftbridge: {
				driver: "nix"

				resources: [{
					memory: 64
					cpu:    200
				}]

				config: [{
					packages: ["github:input-output-hk/cicero#liftbridge"]
					command: ["/bin/liftbridge", "--config", "/local/config.yaml"]
				}]

				template: [{
					destination: "/local/config.yaml"
					data:        yaml.Marshal({
						listen: "0.0.0.0:9292"
						host:   "voter-\(#id).liftbridge.service.consul"
						data: dir: "/local/server"
						activity: stream: enabled: true
						logging: {
							level: "debug"
							raft:  true
						}
						nats: {
							embedded: true
							servers: [
								"nats://voter-0.liftbridge-nats.service.consul:4222",
								"nats://voter-1.liftbridge-nats.service.consul:4222",
								"nats://voter-2.liftbridge-nats.service.consul:4222",
							]
						}
						streams: {
							retention: max: {
								age:      "24h"
								messages: 1000
							}
							compact: enabled: true
						}
						clustering: {
							server: id: "voter-\(#id)"
							raft: bootstrap: seed: #seed
							replica: max: lag: time: "20s"
						}
					})
				}]
			}
		}

		liftbridge0: (#prototype & {#id: 0, #seed: true})
		liftbridge1: (#prototype & {#id: 1, #seed: false})
		liftbridge2: (#prototype & {#id: 2, #seed: false})
	}
}

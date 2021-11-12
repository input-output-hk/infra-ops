package jobs

import (
	"encoding/yaml"
)

job: liftbridge: {
	group: {
		#prototype: {
			#id:   number
			#seed: bool

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
				// clients connections
				port: liftbridge: static: "9292"
				// clients connections
				port: nats: static: "4222"
				// HTTP management port for information reporting and monitoring
				port: http: static: "8222"
				// routing port for clustering
				port: routing: static: "6222"
			}

			service: [{
				name:         "liftbridge"
				address_mode: "host"
				port:         "liftbridge"
				tags: ["voter-\(#id)"]
				canary_tags: ["candidate-\(#id)"]
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
				tags: ["voter-\(#id)"]
				canary_tags: ["candidate-\(#id)"]
				check: [{
					type:     "tcp"
					port:     "nats"
					interval: "10s"
					timeout:  "2s"
				}]
			}]

			task: liftbridge: {
				driver: "nix"

				resources: {
					memory: 128
					cpu:    200
				}

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
							level:    "debug"
							raft:     true
							nats:     true
							recovery: true
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

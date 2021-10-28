package deploy

import (
	jobDefs "github.com/input-output-hk/infra-ops/pkg/jobs:jobs"
)

job: jobDefs.job

for jobName, jobValue in job {
	jobs: "\(jobName)": job: "\(jobName)": jobValue
}

job: [string]: {
	id?:  string
	type: "batch" | "service"
	datacenters: ["eu-central-1", "us-east-2"]
	namespace: "cicero"
	group: [string]: {
		task: [string]: {
			driver: "nix"
			resources: [...#types.resource]
			config: [...#types.config]
		}
	}
}

#types: {
	resource: {
		memory: number
		cpu:    number
	}

	config: {
		nixos?: string
		packages?: [...string]
		command: [...string]
	}
}

package deploy

import (
	jobDefs "github.com/input-output-hk/infra-ops/pkg/jobs:jobs"
)

#config: {
	#sha: string @tag(sha)
}

for jobName, jobValue in #job {
	jobs: "\(jobName)": job: "\(jobName)": {jobValue, #config}
}

#job: [string]: {
	id?:  string
	type: "batch" | *"service"
	datacenters: ["eu-central-1", "us-east-2"]
	namespace: "cicero"
	group: [string]: {
		task: [string]: {
			driver: "nix"
		}
	}
}

#job: jobDefs.job

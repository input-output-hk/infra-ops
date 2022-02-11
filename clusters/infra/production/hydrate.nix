{ lib, ... }: {
  tf.hydrate-cluster.configuration = {
    resource.vault_github_user.cicero-biandratti = {
      backend = "\${vault_github_auth_backend.employee.path}";
      user = "biandratti";
      policies = [ "cicero" ];
    };

    resource.vault_github_user.cicero-rschardt = {
      backend = "\${vault_github_auth_backend.employee.path}";
      user = "rschardt";
      policies = [ "cicero" ];
    };

    locals.policies = {
      consul.developer.servicePrefix."infra-" = {
        policy = "write";
        intentions = "write";
      };

      vault = let
        c = "create";
        r = "read";
        u = "update";
        d = "delete";
        l = "list";
        s = "sudo";
        caps = lib.mapAttrs (n: v: { capabilities = v; });
      in {
        admin.path = caps {
          "secret/*" = [ c r u d l ];
          "auth/github-terraform/map/users/*" = [ c r u d l s ];
          "auth/github-employees/map/users/*" = [ c r u d l s ];
        };

        terraform.path = caps {
          "secret/data/vbk/*" = [ c r u d l ];
          "secret/metadata/vbk/*" = [ d ];
        };

        vit-terraform.path = caps {
          "secret/data/vbk/vit-testnet/*" = [ c r u d l ];
          "secret/metadata/vbk/vit-testnet/*" = [ c r u d l ];
        };

        cicero.path = caps {
          "auth/token/lookup" = [ u ];
          "auth/token/lookup-self" = [ r ];
          "auth/token/renew-self" = [ u ];
          "kv/data/cicero/*" = [ r l ];
          "kv/metadata/cicero/*" = [ r l ];
          "nomad/creds/cicero" = [ r u ];
        };

        client.path = caps {
          "auth/token/create" = [ u s ];
          "auth/token/create/nomad-cluster" = [ u ];
          "auth/token/create/nomad-server" = [ u ];
          "auth/token/lookup" = [ u ];
          "auth/token/lookup-self" = [ r ];
          "auth/token/renew-self" = [ u ];
          "auth/token/revoke-accessor" = [ u ];
          "auth/token/roles/nomad-cluster" = [ r ];
          "auth/token/roles/nomad-server" = [ r ];
          "consul/creds/consul-agent" = [ r ];
          "consul/creds/consul-default" = [ r ];
          "consul/creds/consul-register" = [ r ];
          "consul/creds/nomad-client" = [ r ];
          "consul/creds/vault-client" = [ r ];
          "kv/data/bootstrap/clients/*" = [ r ];
          "kv/data/bootstrap/static-tokens/clients/*" = [ r ];
          "kv/data/nomad-cluster/*" = [ r l ];
          "kv/metadata/nomad-cluster/*" = [ r l ];
          "nomad/creds/nomad-follower" = [ r u ];
          "pki/issue/client" = [ c u ];
          "pki/roles/client" = [ r ];
          "sys/capabilities-self" = [ u ];
        };
      };

      nomad = {
        admin = {
          description = "Admin policies";
          namespace."infra-*".policy = "write";
        };

        developer = {
          description = "Dev policies";
          namespace."infra-*".policy = "write";
        };

        bitte-ci = {
          description = "Bitte CI (Run Jobs and monitor them)";
          namespace.default = {
            policy = "read";
            capabilities =
              [ "submit-job" "dispatch-job" "read-logs" "read-job" ];
          };
          node.policy = "read";
        };

        cicero = {
          description = "Cicero (Run Jobs and monitor them)";
          agent.policy = "read";
          node.policy = "read";
          namespace."*" = {
            policy = "read";
            capabilities =
              [ "submit-job" "dispatch-job" "read-logs" "read-job" ];
          };
        };

        nomad-follower = {
          description = "Nomad Follower (Collect logs from cicero allocations)";
          agent.policy = "read";
          namespace.cicero = {
            policy = "read";
            capabilities = [ "read-job" ];
          };
        };
      };
    };
  };
}

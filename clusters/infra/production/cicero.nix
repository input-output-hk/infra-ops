{ pkgs, ... }: {
  services = {
    postgresql = {
      enable = true;
      enableTCPIP = true;
      package = pkgs.postgresql_13;

      settings = {
        shared_preload_libraries = "pg_stat_statements";
        "pg_stat_statements.track" = "all";
        max_connections = 100;
        shared_buffers = "12800MB";
        effective_cache_size = "38400MB";
        maintenance_work_mem = "2GB";
        checkpoint_completion_target = 0.9;
        wal_buffers = "16MB";
        default_statistics_target = 100;
        random_page_cost = 1.1;
        effective_io_concurrency = 200;
        work_mem = "32MB";
        min_wal_size = "1GB";
        max_wal_size = "4GB";
        max_worker_processes = 16;
        max_parallel_workers_per_gather = 4;
        max_parallel_workers = 16;
        max_parallel_maintenance_workers = 4;
      };

      authentication = ''
        local all all trust
        host all all 10.0.0.0/8 trust
      '';

      initialScript = pkgs.writeText "init.sql" ''
        CREATE DATABASE cicero;
        CREATE USER cicero;
        GRANT ALL PRIVILEGES ON DATABASE cicero to cicero;
        ALTER USER cicero WITH SUPERUSER;

        CREATE ROLE cicero_api;
      '';
    };
  };
}

{ pkgs, ... }:
{
  services.postgresql = {
    enable = true;
    settings = {
      shared_buffers = "1GB";
      effective_cache_size = "3GB";
      work_mem = "4MB";
      maintenance_work_mem = "128MB";
      huge_pages = "try";

      max_wal_size = "1GB";
      min_wal_size = "80MB";
      wal_buffers = "16MB";
      checkpoint_completion_target = "0.9";

      random_page_cost = "1.1";
      effective_io_concurrency = "200";
      track_io_timing = "on";

      max_worker_processes = "2";
      max_parallel_workers_per_gather = "1";
      max_parallel_workers = "2";
      max_parallel_maintenance_workers = "1";

      max_connections = "100";
      default_statistics_target = "100";
      jit = "off";
      shared_preload_libraries = "pg_stat_statements";
    };
  };
}

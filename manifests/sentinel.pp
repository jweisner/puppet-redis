# == Class: redis::sentinel
#
# Installs redis if its not already and configures the sentinel settings.
#
# === Parameters
#
# $redis_clusters - This is a hash that defines the redis clusters
# $service_name - Sentinel service name
# that sentinel should watch.
#
# === Examples
#
# class { 'redis::sentinel': }
#
# redis::sentinel::redis_clusters:
#  'claims':
#    master_ip: '192.168.33.51'
#    down_after: 30000
#    failover_timeout: 180000
#  'monkey':
#    master_ip: '192.168.33.54'
#    down_after: 30000
#    failover_timeout: 180000
#
# === Authors
#
# Dan Sajner <dsajner@covermymeds.com>
#
class redis::sentinel (
  $config_file    = '/etc/sentinel.conf',
  $version        = 'installed',
  $service_name   = 'sentinel',
  $redis_clusters = undef,
) {

  # Install the redis package
  ensure_packages(['redis'], { 'ensure' => $version })

  # Declare the sentinel config file here so we can manage ownership
  file { $config_file:
    ensure  => present,
    owner   => 'redis',
    group   => 'root',
    require => Package['redis'],
  }

  # Sentinel rewrites its config file so we lay this one down initially.
  # This allows us to manage the configuration file upon installation
  # and then never again.
  file { "${config_file}.puppet":
    ensure  => present,
    owner   => 'redis',
    group   => 'root',
    mode    => '0644',
    content => template('redis/sentinel.conf.erb'),
    require => Package['redis'],
    notify  => Exec['cp_sentinel_conf'],
  }

  exec { 'cp_sentinel_conf':
    command     => "/bin/cp ${config_file}.puppet ${config_file}",
    refreshonly => true,
    notify      => Service[sentinel],
  }

  # Run it!
  service { 'sentinel':
    ensure     => running,
    enable     => true,
    name       => $service_name,
    hasrestart => true,
    hasstatus  => true,
    require    => Package['redis'],
  }

  # Lay down the runtime configuration script
  $config_script = '/usr/local/bin/sentinel_config.sh'

  file { $config_script:
    ensure  => present,
    owner   => 'redis',
    group   => 'root',
    mode    => '0755',
    content => template('redis/sentinel_config.sh.erb'),
    require => Package['redis'],
    notify  => Exec['configure_sentinel'],
  }

  # Apply the configuration. 
  exec { 'configure_sentinel':
    command     => $config_script,
    refreshonly => true,
    require     => [ Service['sentinel'], File[$config_script] ],
  }

}


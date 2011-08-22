file { "/etc/apt/sources.list.d/fort.list":
    ensure  => present,
    owner   => "root",
    group   => "root",
    content => template("apt/fort.list"),
    notify  => Exec["apt-get-update"],
}

exec { "apt-get-update":
    command     => "/usr/bin/apt-get update",
    refreshonly => true,
}


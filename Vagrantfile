# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure('2') do |config|
  config.vm.box = 'ubuntu/xenial64'
  config.vm.network 'private_network', ip: '33.33.33.10'
  config.vm.synced_folder '.', '/vagrant', :owner => 'vagrant', :group => 'www-data', :mount_options => ['dmode=774','fmode=775']

  config.vm.provider 'virtualbox' do |vb|
    vb.gui = false
    vb.memory = '1024'
  end

  config.vm.provision :shell, path: 'bootstrap.sh'
end

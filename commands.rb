require "net/scp"
require "open-uri"

default_ip = `ping raspberrypi.local -c 1 | head -n 1`.split("(").last.split(")").first

puts
puts "Enter target ip (#{default_ip}):"
print "> "
@ip = gets.chomp
@ip = default_ip if @ip.empty?

puts
puts "Enter hostname:"
print "> "
@hostname = gets.chomp
raise ArgumentError.new("You must enter a hostname.") if @hostname.empty?

default_password = "grafanacon"
puts
puts "Enter new password (#{default_password}):"
print "> "
@password = gets.chomp
@password = default_password if @password.empty?

puts
puts "Share NFS? (nY):"
print "> "
@share_nfs = gets.chomp.downcase
@share_nfs = "n" if @share_nfs.empty?

@nfs_path = "/var/#{@hostname}-data"
@mask     = @ip.gsub(/\.\d+$/, ".1/24")

DHCP=<<EOF
interface eth0
static ip_address=#{@ip}/24
static routers=#{@mask.split("/").first}
static domain_name_servers=1.1.1.1
EOF

Net::SCP.start(@ip, "pi", password: "raspberry") do |scp|
  ssh = scp.session
  ssh.exec("sudo apt-get update && \
            sudo apt-get upgrade -y && \
            sudo apt-get install -y nfs-kernel-server")
  ssh.loop

  keys = URI.open("https://github.com/thejonanshow.keys", &:read)

  files = {}
  files[:dhcp] = StringIO.new.tap { |io| io.set_encoding 'BINARY'}
  files[:fstab] = StringIO.new.tap { |io| io.set_encoding 'BINARY'}
  files[:exports] = StringIO.new.tap { |io| io.set_encoding 'BINARY'}
  files[:hosts] = StringIO.new.tap { |io| io.set_encoding 'BINARY'}
  files[:hostname] = StringIO.new.tap { |io| io.set_encoding 'BINARY'}
  files[:authorized_keys] = StringIO.new(keys).tap { |io| io.set_encoding 'BINARY'}

  downloads = [
    scp.download("/etc/dhcpcd.conf", files[:dhcp]),
    scp.download("/etc/fstab", files[:fstab]),
    scp.download("/etc/hosts", files[:hosts]),
    scp.download("/etc/hostname", files[:hostname])
  ].each { |d| d.wait }

  ssh.exec("sudo mkdir -p /home/pi/.ssh")
  ssh.exec("sudo mkdir -p #{@nfs_path}")

  hosts = files[:hosts].string.gsub("raspberrypi", @hostname)
  hostname = files[:hostname].string.gsub("raspberrypi", @hostname)
  dhcp = files[:dhcp].string << "\n#{DHCP}"
  fstab = files[:fstab].string << "\n/dev/sda1 /var/#{@hostname}-data ext4 defaults,noatime 0 2"
  exports = files[:exports].string << "#{@nfs_path} #{@mask} (rw,sync,no_root_squash,no_subtree_check)"

  files[:dhcp] = StringIO.new(dhcp).tap { |io| io.set_encoding 'BINARY' }
  files[:fstab] = StringIO.new(fstab).tap { |io| io.set_encoding 'BINARY' }
  files[:exports] = StringIO.new(exports).tap { |io| io.set_encoding 'BINARY' }
  files[:hosts] = StringIO.new(hosts).tap { |io| io.set_encoding 'BINARY' }
  files[:hostname] = StringIO.new(hostname).tap { |io| io.set_encoding 'BINARY' }

  uploads = [
    scp.upload(files[:dhcp],            "/tmp/dhcpcd.conf"),
    scp.upload(files[:hosts],           "/tmp/hosts"),
    scp.upload(files[:hostname],        "/tmp/hostname"),
    scp.upload(files[:authorized_keys], "/tmp/authorized_keys")
  ]

  if @share_nfs == "y"
    uploads << scp.upload(files[:fstab],   "/tmp/fstab")
    uploads << scp.upload(files[:exports], "/tmp/exports")
  end

  ssh.loop

  uploads.each { |u| u.wait }

  ssh.exec("sudo mv /tmp/dhcpcd.conf /etc/dhcpcd.conf")
  ssh.exec("sudo mv /tmp/fstab /etc/fstab")
  ssh.exec("sudo mv /tmp/hosts /etc/hosts")
  ssh.exec("sudo mv /tmp/exports /etc/exports")
  ssh.exec("sudo mv /tmp/hostname /etc/hostname")
  ssh.exec("sudo mv /tmp/authorized_keys /home/pi/.ssh/authorized_keys")
  ssh.exec("sudo chmod 700 /home/pi/.ssh")

  ssh.loop

  ssh.exec!("sudo chmod 600 /home/pi/.ssh/authorized_keys")
  ssh.exec!("sudo chown pi:pi -R /home/pi/.ssh")

  crypt_cmd = "python3 -c 'import crypt; print("
  crypt_cmd << "crypt.crypt('#{@password}', crypt.mksalt(crypt.METHOD_SHA512)))'"
  hashed = ssh.exec!(crypt_cmd)
  ssh.exec!("printf $'pi:#{@hashed_password}' | sudo chpasswd --encrypted")

  ssh.loop
end

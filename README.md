# DANGER 🔥

If I were you I would probably not use this script to connect to anything
important, or maybe anything. If you have some Raspberry Pis with a fresh
install of Raspbian Lite and you're looking to get a k3s cluster quickly AND
you're feeling very, very brave try this script.

You might want to modify a Raspbian card to clone from with your
locale settings and such beforehand, but this should work anyway.

1. Burn Raspbian Lite with Etcher (https://www.balena.io/etcher/)
2. Remove and reinsert SD card to mount it.
3. `touch /Volumes/boot/ssh` (on OS X)
4. Eject the drive with Finder.
5. Insert card, boot pi and run this script with `ruby command.rb`
6. Reboot the Pi so it uses the new hostname
7. Install k3s with k3sup (https://github.com/alexellis/k3sup)

Note that these IPs probably don't apply to you and will need
to be changed. I've certainly hardcoded things in the commands.rb
file that you'll want to swap out as well. You're going to
have a bad time if you try to connect to your cluster with
my public keys for example. 😂

## k3sup Installer

Setup primary:
```
export SERVER_IP=192.168.1.170
export USER=pi

k3sup install --ip $SERVER_IP --user $USER
```

### EXPORT the kubeconfig - don't forget this step and make a movie about it:

```
export KUBECONFIG=`pwd`/kubeconfig
kubectl get node
```

Add some helpers:
```
export AGENT_IP=192.168.1.171

export SERVER_IP=192.168.0.170
export USER=pi

k3sup join --ip $AGENT_IP --server-ip $SERVER_IP --user $USER
```

If you want to make this script better with a PR I'd really appreciate it.

## Fight COVID with your new drones! Thanks Balena!

https://foldforcovid.io/

### TODO: Burn this down and try it in Go.

MIT LICENSE (me) 2020 <- Very Official

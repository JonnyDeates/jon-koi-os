{
config,
pkgs,
...
}: {
  environment.systemPackages =
    with pkgs; [
          minikube
          kubernetes
          kubernetes-helm
    ];
}
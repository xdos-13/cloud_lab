### Canary

All the canary files are in the directory canary/

#### Setup Istio

You can follow the official link https://istio.io/ to download istio.
```bash
curl -L https://istio.io/downloadIstio | sh -
cd istio-*
export PATH=$PWD/bin:$PATH
istioctl install --set profile=demo -y
```


#### Prepare Version 1
Labelling the first version:

```bash
kubectl patch deployment productcatalogservice -p '{"spec":{"template":{"metadata":{"labels":{"version":"v1"}}}}}'
```

#### Deploy v2

We add the changes to the files for the version 2. We chose productcatalogservice.
We rebuild the docker image for the v2, and then push it.
```bash 
docker build -t gcr.io/hybrid-text-484416-t4/productcatalogservice:v2 . 
docker push gcr.io/hybrid-text-484416-t4/productcatalogservice:v2
kubectl apply -f productcatalogservice-v2.yaml
```

#### Configure Canary traffic

We apply Istio configuration to define the subsets and split 75% to v1 and 25% to v2

```bash
kubectl apply -f canary-rules.yaml
```
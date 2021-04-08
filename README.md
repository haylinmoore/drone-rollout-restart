# What is it
`drone-rollout-restart` is a [Drone CI](https://www.drone.io/) plugin (aka. a container) that let's you do a `kubectl rollout restart` command during a build in drone.
This is useful if you want to automatically rollout a newly built image, and you're kubernetes cluster is pulling from latest for that image.
If you want to use versioned images or you want something that runs a command like this: `kubectl set image deployment/nginx-deployment nginx=nginx:1.9.1` [drone-kubernetes](https://github.com/honestbee/drone-kubernetes) is what you're looking for.
If you find any of this documentation insufficient you can look at [drone-kubernetes](https://github.com/honestbee/drone-kubernetes) for more information because their project is quite similar.

# How to use drone-rollout-restart

## Prerequisites
This README assumes you have kubectl access to the cluster you're trying to set up with `drone-rollout-restart`.

To use `drone-rollout-restart` you'll need to have a service account that the `drone-rollout-restart` container can use to run the rollout command.
You can create a service account with the proper permissions like this:
```yaml
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: my-app-deployer # Name of the service account
  namespace: my-app     # Namespace to hold the ServiceAccount

---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: my-app-deployer  # Name of the role
  namespace: my-app      # Namespace to hold the Role
rules:
  - apiGroups: ["apps"]
    resources: ["deployments"] # It needs permissions over deployments
    verbs: ["get","patch"] # This is a minimal set of verbs that drone-rollout-restart requires

---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: my-app-binding # Name of the RoleBinding
  namespace: my-app    # Namespace to hold the RoleBinding
subjects:
  - kind: ServiceAccount
    name: my-app-deployer # Name of the ServiceAccount to bind to
    namespace: my-app     # Namespace containing the ServiceAccount "my-app-deployer"
roleRef:
  kind: Role
  name: my-app-deployer # Name of the Role to bind to the ServiceAccount
  apiGroup: rbac.authorization.k8s.io
```

## Example
In your drone pipeline define a step like this:
```yaml
- name: rollout
  image: toxicglados/drone-rollout-restart:latest # This is public and on Dockerhub. You're welcome to build and upload your own.
  pull: always
  settings:
    deployment: my-deployment-name
    namespace: my-namespace-name
    kubernetes_server:
      from_secret: KUBERNETES_SERVER # Pulling these from secrets isn't required, but strongly encouraged
    kubernetes_cert:
      from_secret: KUBERNETES_CERT
    kubernetes_token:
      from_secret: KUBERNETES_TOKEN
```
This has the effect of running a `kubectl rollout restart deployment my-deployment-name -n my-namespace-name` command against the cluster provided by `kubernetes_server` with the credentials of the owner of the token provided by `kubernetes_token`.

## Settings description

* `deployment`: The name of the deployment to run the `rollout restart` against.

  Examples: `my-app`, `blog`, `webserver`
* `namespace` (optional): The namespace to run the `rollout restart` against.
If not defined it will default to "default".

  Examples: `my-app`, `blog`, `webserver`
* `kubernetes_server`: Defines the hostname or ip and port of the kubernetes server.

  Examples: `192.168.0.150:6443`, `myk8sdomain.com`, `cooldomainname.com:6443`
* `kubernetes_cert` (optional): The certificate authority to use when connecting to the cluster.
Although optional, highly recommended.
See below for instructions on obtaining it from your cluster if you don't know how to obtain it.

  Examples: See **Getting the token and cert values** section below. 
* `kubernetes_token`: The barer token that represents the service account that this command should be run as.
See below for instructions on obtaining it from your cluster if you don't know how to obtain it.

  Examples: See **Getting the token and cert values** section below. 


## Getting the token and cert values
After deploying the service account get the secrets for the name space you deployed the service account to (Namespace=`my-app`, ServiceAccount=`my-app-deployer` above).

```bash
> kubectl get secret -n my-app
NAME                          TYPE                                  DATA   AGE
default-token-prdm4           kubernetes.io/service-account-token   3      7d20h
my-app-deployer-token-q694v   kubernetes.io/service-account-token   3      5h51m
```

You can ignore the default service account's token. Now actually output the secret. WARNING: These are sensitive values and you should make sure to keep them secret. The values I show here are just random data, so your cert and token might appear slightly different.
```bash
> k get secret -n blog blog-deployer-token-q694v -o yaml | egrep 'ca.crt:|token:'
ca.crt: araPBpAOb/b0Hjg7QnF9YjEQWjZgphQuGCBp59OsxY271QZfVg39XUlx5LnfEzk2q932labTLPWBFFk7RdhcnLJJSrVu27EcMmbWI6gLrZ8/YsCaU3DmDAE7nuMc5bsIQs+LL94cnr8FZsFIvahGQX5hu/fkmq37KISaFNPvSbyyQPeDBrV2gDfdM6/28I3ErNyqahKNP7xN6COZXyWr2bfuQaKgOTwJh2P+XVfQEs6YHZpKvh77losjzbpsc4HaVzNw6Sb4zTPLd3z9SFISFYFBTG30P9UBp1XyHkdULjmcmRO+Prqdl/i33mrFApnGT6dgsT89PI73UUJwxAs4sor4GDhmVv022/vOm9cfYke18fuvN0WykCZMgttAvfenDC0pQChbtW1orW8VwV4A0VusN1pNMaiz8YMPq6MpHhV4UnhQzWx8zpq+MuPsLJqjpLKoE4g6ehjF5IfzCjl+1eky83yvPVnEfWtQIMNeDQNzUcKBDGzcyg1YZnUNvFve5MMgS34iwYioJuCOStxUkW6KTfJme56oPomqExuhnGewTJkxBefKizxjD2YRCkTVF436EzP1q+9i4DHZl1T5/NgEg3eb0axQByrVHS6a6V1AEqliZJPonZi4/HjPc2BB9s9/FT0z6ypP8vfYTdep/FTzkt7AfAkb4n18Tg9MOpaqGQL2qH9c9d/seU/V63qG+CysJS+DFrgMzXgU+C+6jRIPkiaOqK5NQkBAuVEj04QkGW9dZBB0b # This is your cert

token:NWRtVFM5NzNoT2J5Y0JrQTgxYWNTc25tYW5QSlBlM0Z5RWZSeXQ3Q014dUNQL1NwZXNwM250Vm4wRTJ1ZXhKNFp5TGRUSU9TV3ZENTRJU2FSTXBvVXYvTnB1WVpIWXpkMHBPNk8zVk03Q2RpN2toNHNobWVkSHRvbzJnV3VjeS9YZVE0OVJYOHJ2UTF4emR3aEFubGhwZTBXb2J1UFZ3WWxFRFg1Z2JJZXRvOTRobzF5ZnpveG5yRFVsSnBwRDJnQ1JXNFhTeEw4ZlBEbTZ1aFlGMFZtT2UzbllYL01EUnB3Z2M0Wm1FaCtzaUlVSzQxMTc4UEN4RVo1QWVtYmk1ZG5ZMzN1SlZIc29FT0tQZTFuOVBiRTBpVXF2MUsvc0pZZGpoamhiczdReUlxYnZjZjF5bW5kYlRlZXlpZDFnbVk2NUg3OURucXBQS3ZLZ2tvQTVCVnlGa1ZjV09rRktlNFhYcjJuLy9rUmU5dG5Rd0I0WkV5dWIwaHh3YURkMTE1TmFnb0pJUkNuRERxdTNUUjAxcXV6dGR4Q1dBOXdvYXdjUWNxUjdEUlBkVEVIR1pVeFAwNVY5VTY5bVpwNHl2U281bDArRWVkUUlpMldZbEMzYk9zdW1FMGtpVW1mYVU1bS9RaEwxVE9lcGtwVjJGenlzQnc0VzZzSlYrNzN3bEoxN2hKM3l4alZBcXBHcVMvOFBPZFQ0NGY1WTFpbXNVZDgwMkN0R3YzU0ZtSTlXQWhhdUFwSktRTTcxVDFCRndMb1BhNE1pV3hqMWRrSTBTVDBUT0NGeS9mZ2pQM25uY2VWVUJqc3NuSmkwTmxaMTQ2UmNxV3prZVdKckhSWWhUQitGaE83SkhPNXRVRmdPMkFtWGM2SFhoelJGR3JqdDFZcmVpMUpWdURPV2pjcHBZOFF1MjRKQ3AyblZNbHd2ZTBqV0NFZ3NTbW45MXoyV0sybTBZb0Q3a3RFUk1VdDFIMzB5c3lLUTFhOUVRZ1gvdXNkejJ2b052QkJWNkNMV0VrZS9MaWFHTnZSeUtESWNTVUhqa1RCbVJOU2RHT2FKNnZORlZTQWpUanRmaWRSZTE4ekQ2S2ZOMUgxMjJmSzcxOG9Ka0F4bnlvNjltV04yQW9ETXc2cUJUR0dQZ2JJWFhXRXFYYjIzbmFFMGxUaWpFOG9yM0hQdmRJTHB4UUpGU01FVXlpOTZGMExPMGd5ZGplVTAxQTd6a # This is your ServiceAccount's base64 encoded token
```

Decode the token:
```bash
> echo -n 'NWRtVFM5NzNoT2J5Y0JrQTgxYWNTc25tYW5QSlBlM0Z5RWZSeXQ3Q014dUNQL1NwZXNwM250Vm4wRTJ1ZXhKNFp5TGRUSU9TV3ZENTRJU2FSTXBvVXYvTnB1WVpIWXpkMHBPNk8zVk03Q2RpN2toNHNobWVkSHRvbzJnV3VjeS9YZVE0OVJYOHJ2UTF4emR3aEFubGhwZTBXb2J1UFZ3WWxFRFg1Z2JJZXRvOTRobzF5ZnpveG5yRFVsSnBwRDJnQ1JXNFhTeEw4ZlBEbTZ1aFlGMFZtT2UzbllYL01EUnB3Z2M0Wm1FaCtzaUlVSzQxMTc4UEN4RVo1QWVtYmk1ZG5ZMzN1SlZIc29FT0tQZTFuOVBiRTBpVXF2MUsvc0pZZGpoamhiczdReUlxYnZjZjF5bW5kYlRlZXlpZDFnbVk2NUg3OURucXBQS3ZLZ2tvQTVCVnlGa1ZjV09rRktlNFhYcjJuLy9rUmU5dG5Rd0I0WkV5dWIwaHh3YURkMTE1TmFnb0pJUkNuRERxdTNUUjAxcXV6dGR4Q1dBOXdvYXdjUWNxUjdEUlBkVEVIR1pVeFAwNVY5VTY5bVpwNHl2U281bDArRWVkUUlpMldZbEMzYk9zdW1FMGtpVW1mYVU1bS9RaEwxVE9lcGtwVjJGenlzQnc0VzZzSlYrNzN3bEoxN2hKM3l4alZBcXBHcVMvOFBPZFQ0NGY1WTFpbXNVZDgwMkN0R3YzU0ZtSTlXQWhhdUFwSktRTTcxVDFCRndMb1BhNE1pV3hqMWRrSTBTVDBUT0NGeS9mZ2pQM25uY2VWVUJqc3NuSmkwTmxaMTQ2UmNxV3prZVdKckhSWWhUQitGaE83SkhPNXRVRmdPMkFtWGM2SFhoelJGR3JqdDFZcmVpMUpWdURPV2pjcHBZOFF1MjRKQ3AyblZNbHd2ZTBqV0NFZ3NTbW45MXoyV0sybTBZb0Q3a3RFUk1VdDFIMzB5c3lLUTFhOUVRZ1gvdXNkejJ2b052QkJWNkNMV0VrZS9MaWFHTnZSeUtESWNTVUhqa1RCbVJOU2RHT2FKNnZORlZTQWpUanRmaWRSZTE4ekQ2S2ZOMUgxMjJmSzcxOG9Ka0F4bnlvNjltV04yQW9ETXc2cUJUR0dQZ2JJWFhXRXFYYjIzbmFFMGxUaWpFOG9yM0hQdmRJTHB4UUpGU01FVXlpOTZGMExPMGd5ZGplVTAxQTd6a' | base64 --decode
5dmTS973hObycBkA81acSsnmanPJPe3FyEfRyt7CMxuCP/Spesp3ntVn0E2uexJ4ZyLdTIOSWvD54ISaRMpoUv/NpuYZHYzd0pO6O3VM7Cdi7kh4shmedHtoo2gWucy/XeQ49RX8rvQ1xzdwhAnlhpe0WobuPVwYlEDX5gbIeto94ho1yfzoxnrDUlJppD2gCRW4XSxL8fPDm6uhYF0VmOe3nYX/MDRpwgc4ZmEh+siIUK41178PCxEZ5Aembi5dnY33uJVHsoEOKPe1n9PbE0iUqv1K/sJYdjhjhbs7QyIqbvcf1ymndbTeeyid1gmY65H79DnqpPKvKgkoA5BVyFkVcWOkFKe4XXr2n//kRe9tnQwB4ZEyub0hxwaDd115NagoJIRCnDDqu3TR01quztdxCWA9woawcQcqR7DRPdTEHGZUxP05V9U69mZp4yvSo5l0+EedQIi2WYlC3bOsumE0kiUmfaU5m/QhL1TOepkpV2FzysBw4W6sJV+73wlJ17hJ3yxjVAqpGqS/8POdT44f5Y1imsUd802CtGv3SFmI9WAhauApJKQM71T1BFwLoPa4MiWxj1dkI0ST0TOCFy/fgjP3nnceVUBjssnJi0NlZ146RcqWzkeWJrHRYhTB+FhO7JHO5tUFgO2AmXc6HXhzRFGrjt1Yrei1JVuDOWjcppY8Qu24JCp2nVMlwve0jWCEgsSmn91z2WK2m0YoD7ktERMUt1H30ysyKQ1a9EQgX/usdz2voNvBBV6CLWEke/LiaGNvRyKDIcSUHjkTBmRNSdGOaJ6vNFVSAjTjtfidRe18zD6KfN1H122fK718oJkAxnyo69mWN2AoDMw6qBTGGPgbIXXWEqXb23naE0lTijE8or3HPvdILpxQJFSMEUyi96F0LO0gydjeU01A7z # This is your ServiceAccount's token
```

The cert is supposed to be base64 encoded so there's no need to decode that. Now you have values for `kubernetes_token`, and `kubernetes_cert`.

Don't forget to put those values in the secrets section of your repo in drone to use them in the pipeline.

For more help check out [drone-kubernetes](https://github.com/honestbee/drone-kubernetes)'s README.

# Security Implications
Any RBAC permissions the drone-runner ServiceAccount (not to be confused with the ServiceAccount you're deploying for your app deployment) has can be used by this container, which makes it possible to just add RBAC permissions to the already existing drone-runner ServiceAccount instead of creating a new one.
**This should be avoided**.
If you give permissions to the drone-runner ServiceAccount any drone pipeline on your drone server will be able to run rollouts against your deployment without the token.


# Credit
Although the code has been modified quite a bit, I started by using [drone-kubernetes](https://github.com/honestbee/drone-kubernetes) as a reference, so thanks to them :)


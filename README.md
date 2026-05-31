Infrastructure Monorepo
===

This monorepo includes all config and links in services that are 
run in the following hosts:
	+ nandimitra

Run the following in `nix-deploy` to create the wrapperr `supervisord` 
that starts all services that are linked from the mono repo. 

```
nix build
```

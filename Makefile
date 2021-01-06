default: help

.PHONY : package
package :
	cd products/${HC_PRODUCT} && ./package.sh

.PHONY : local-package
local-package :
	cd products/vault_selinux && HC_VERSION=0.0.1 LOCAL_PACKAGE=1 ./package.sh

.PHONY : help
help :
	@echo "Placeholder for help output"

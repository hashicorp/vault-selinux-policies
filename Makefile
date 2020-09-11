default: help

.PHONY : package
package :
	cd products/${HC_PRODUCT} && ./package.sh

.PHONY : help
help :
	@echo "Placeholder for help output"

# This file is included from the main makefile and should be customized.

# Define the set of repositories for rendered code. The pattern should be:
# protobuf-SERVICE-LANGUAGE
# where SERVICE is named serice (ex: customer, product, etc.) and LANGUAGE
# is a supported rendered language (ex: go (golang), ts (typescript), php).
REPOS = \
protobuf-first-go \
protobuf-first-ts \
protobuf-first-php \
protobuf-second-go \
protobuf-second-ts \
protobuf-third-go \
protobuf-third-ts

# The package prefix is used as a prefix for rendered code and should 
# match the directory prefix for proto files.  Typically it might
# be the name of a company.
PACKAGE_PREFIX = caseylucas

# If there inter-service dependencies that should also be packaged
# up into a typescript repo, include the other rendered files by setting a variable like
# OTHER_TS_DEPS_packaged =  other_repsitory
# Ex: This will cause service1 rendered files to be included in the service2 repository:
# OTHER_TS_DEPS_service2 = service1
#
# Add other/additional directories that should be packaged as typescript/javascript dependencies.
OTHER_TS_DEPS_third = second

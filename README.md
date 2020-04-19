# protobuf - Rendering protobuf files

This repository is associated with [a blog post](https://www.caseylucas.com/2020/04/16/rendering-grpc-protobuf-files.html).
Please see the post for some background.
Here you'll find a Makefile, script, and some example configurations for using prototool to render gRPC protobuf
files into separate repositories for different languages (go, typescript, and php).

## Setup

1. Be sure to have docker running and git, curl, and jq available.
2. Create a [personal access token for accessing github](https://help.github.com/en/github/authenticating-to-github/creating-a-personal-access-token-for-the-command-line)
and set a GITHUB_TOKEN environment variable. This is required for creating rendered code github repos.
3. Clone/fork this repo or simply copy the desired files (Makefile, etc.)
4. Create a PACKAGE_PREFIX (typically your company name) directory for your protobuf definitions
and then a subdirectory (PACKAGE_PREFIX/service) for each service.  In this repo, `PACKAGE_PREFIX=caseylucas`.
5. Modify `rendered_repos.mk` to suit your service names and desired language renderings.

## Use

Run `make` to show useful make targets.  Ex:

```
Make targets:
- generate: Runs prototool in order to validate / lint all *.proto files
- repos:    Create required protobuf-* github repos
- diff:     Show diff of *generated* code. Does not commit changes - just shows diff
- commit:   Commits (and pushes) generated code (NOT *.proto files)
- clean:    Cleans up intermediate files
- help:     Print this help

When adding a *new* folder, you'll need to edit rendered_repos.mk and add to the REPOS variable. Be sure to add
a protobuf-X-L for every X service with desired language L.

Typically you can use 'make generate' while you are working issues out.  Then run 'make diff' to view the
rendered code changes. Finally run 'make commit' to commit/push rendered code changes.
```

### New Service

If you are defining a new service, you'll need to:

1. Create the new protobuf file(s) in PACKAGE_PREFIX/SERVICE directory.
2. Add desired renderings (ex: protobuf-SERVICE-go and/or protobuf-SERVICE-ts) to `rendered_repos.mk`.
3. Run `make repos` to automatically create the github projects.

### Protobuf Modifications

When creating new service definitions or altering existing ones, you'll typically run
```bash
make generate
```
to generate and lint protobuf files.  This is typically an iterative process. Nothing will be
committed when running `make generate`.

After you're happy with the protobuf modifications, you can push them to the rendered repos
by running:
```
make commit
```

If you want to see differences in rendered code before committing, you can run:
```
make diff
```

## More advanced cases

You may need to modify prototool.yaml to suit your needs, especially if you have inter-service dependencies.
See comments in prototool.yaml for more info.


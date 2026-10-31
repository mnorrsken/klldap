build-dev-container:
	docker buildx build --platform linux/amd64 --tag ghcr.io/mnorrsken/klldap-rust-dev:$$(sha256sum .github/workflows/Dockerfile.dev | cut -c1-12) --file .github/workflows/Dockerfile.dev --push .github/workflows

prepare-release:
	./prepare-release.sh

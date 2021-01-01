LAST_TAG=$(shell git describe --abbrev=0 --tags)
CURR_SHA=$(shell git rev-parse --verify HEAD)

LDFLAGS=-ldflags "-s -w -X main.version=$(LAST_TAG)"
BUILD_DIR=./builds

.PHONY: data test lint install rules setup bench compare release

all: build

# make release tag=v0.4.3
release:
	git tag $(tag)
	git push origin $(tag)

# make build os=darwin
# make build os=windows
# make build os=linux
build:
	GOOS=$(os) GOARCH=amd64 go build ${LDFLAGS} -o bin/$(exe) ./cmd/vale

gcc:
	GOOS=$(os) GOARCH=amd64 go build -compiler gccgo -gccgoflags "-s -w" -o bin/$(exe) ./cmd/vale

bench:
	go test -bench=. -benchmem ./core ./lint ./check

compare:
	cd lint && \
	benchmany -n 5 -o new.txt ${CURR_SHA} && \
	benchmany -n 5 -o old.txt ${LAST_TAG} && \
	benchcmp old.txt new.txt && \
	benchstat old.txt new.txt

setup:
	bundle install
	gem specific_install -l https://github.com/jdkato/aruba.git -b d-win-fix

rules:
	go-bindata -ignore=\\.DS_Store -pkg="rule" -o rule/rule.go rule/**/*.yml

data:
	go-bindata -ignore=\\.DS_Store -pkg="data" -o data/data.go data/*.{dic,aff}

test:
	go test -race ./internal/core ./internal/lint ./internal/check ./pkg/glob
	cucumber

docker:
	GOOS=linux GOARCH=amd64 go build ${LDFLAGS} -o bin/vale
	docker login -u jdkato -p ${DOCKER_PASS}
	docker build -f Dockerfile -t jdkato/vale:latest .
	docker tag jdkato/vale:latest jdkato/vale:${LAST_TAG}
	docker push jdkato/vale

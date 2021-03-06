.PHONY: prebuild clean cleanall ci server server-mac server-linux server-win server-linux-package generate watch-server webapp mac-app win-app linux-app

PACKAGE_FOLDER = focalboard

# Build Flags
BUILD_NUMBER ?= $(BUILD_NUMBER:)
BUILD_DATE = $(shell date -u)
BUILD_HASH = $(shell git rev-parse HEAD)
# If we don't set the build number it defaults to dev
ifeq ($(BUILD_NUMBER),)
	BUILD_NUMBER := dev
endif

LDFLAGS += -X "github.com/mattermost/focalboard/server/model.BuildNumber=$(BUILD_NUMBER)"
LDFLAGS += -X "github.com/mattermost/focalboard/server/model.BuildDate=$(BUILD_DATE)"
LDFLAGS += -X "github.com/mattermost/focalboard/server/model.BuildHash=$(BUILD_HASH)"

all: server

prebuild:
	cd webapp; npm install

ci: server-test
	cd webapp; npm run check
	cd webapp; npm run test
	cd webapp; npm run cypress:ci

server:
	$(eval LDFLAGS += -X "github.com/mattermost/focalboard/server/model.Edition=dev")
	cd server; go build -ldflags '$(LDFLAGS)' -o ../bin/focalboard-server ./main

server-mac:
	mkdir -p bin/mac
	$(eval LDFLAGS += -X "github.com/mattermost/focalboard/server/model.Edition=mac")
	cd server; env GOOS=darwin GOARCH=amd64 go build -ldflags '$(LDFLAGS)' -o ../bin/mac/focalboard-server ./main

server-linux:
	mkdir -p bin/linux
	$(eval LDFLAGS += -X "github.com/mattermost/focalboard/server/model.Edition=linux")
	cd server; env GOOS=linux GOARCH=amd64 go build -ldflags '$(LDFLAGS)' -o ../bin/linux/focalboard-server ./main

server-win:
	$(eval LDFLAGS += -X "github.com/mattermost/focalboard/server/model.Edition=win")
	cd server; env GOOS=windows GOARCH=amd64 go build -ldflags '$(LDFLAGS)' -o ../bin/win/focalboard-server.exe ./main

server-linux-package: server-linux webapp
	rm -rf package
	mkdir -p package/${PACKAGE_FOLDER}/bin
	cp bin/linux/focalboard-server package/${PACKAGE_FOLDER}/bin
	cp -R webapp/pack package/${PACKAGE_FOLDER}/pack
	cp server-config.json package/${PACKAGE_FOLDER}/config.json
	cp build/MIT-COMPILED-LICENSE.md package/${PACKAGE_FOLDER}
	cp NOTICE.txt package/${PACKAGE_FOLDER}
	cp webapp/NOTICE.txt package/${PACKAGE_FOLDER}/webapp-NOTICE.txt
	mkdir -p dist
	cd package && tar -czvf ../dist/focalboard-server-linux-amd64.tar.gz ${PACKAGE_FOLDER}
	rm -rf package

server-single-user:
	$(eval LDFLAGS += -X "github.com/mattermost/focalboard/server/model.Edition=dev")
	cd server; go build -ldflags '$(LDFLAGS)' -o ../bin/focalboard-server ./main --single-user

server-mac-single-user:
	mkdir -p bin/mac
	$(eval LDFLAGS += -X "github.com/mattermost/focalboard/server/model.Edition=mac")
	cd server; env GOOS=darwin GOARCH=amd64 go build -ldflags '$(LDFLAGS)' -o ../bin/mac/focalboard-server ./main --single-user

server-linux-single-user:
	mkdir -p bin/linux
	$(eval LDFLAGS += -X "github.com/mattermost/focalboard/server/model.Edition=linux")
	cd server; env GOOS=linux GOARCH=amd64 go build -ldflags '$(LDFLAGS)' -o ../bin/linux/focalboard-server ./main --single-user

server-win-single-user:
	$(eval LDFLAGS += -X "github.com/mattermost/focalboard/server/model.Edition=win")
	cd server; env GOOS=windows GOARCH=amd64 go build -ldflags '$(LDFLAGS)' -o ../bin/focalboard-server.exe ./main --single-user

generate:
	cd server; go get -modfile=go.tools.mod github.com/golang/mock/mockgen
	cd server; go get -modfile=go.tools.mod github.com/jteeuwen/go-bindata
	cd server; go generate ./...

server-lint:
	@if ! [ -x "$$(command -v golangci-lint)" ]; then \
        echo "golangci-lint is not installed. Please see https://github.com/golangci/golangci-lint#install for installation instructions."; \
        exit 1; \
    fi; \
	cd server; golangci-lint run -p format -p unused -p complexity -p bugs -p performance -E asciicheck -E depguard -E dogsled -E dupl -E funlen -E gochecknoglobals -E gochecknoinits -E goconst -E gocritic -E godot -E godox -E goerr113 -E goheader -E golint -E gomnd -E gomodguard -E goprintffuncname -E gosimple -E interfacer -E lll -E misspell -E nlreturn -E nolintlint -E stylecheck -E unconvert -E whitespace -E wsl --skip-dirs services/store/sqlstore/migrations/ ./...

server-test:
	cd server; go test -v ./...

server-doc:
	cd server; go doc ./...

watch-server:
	cd server; modd

watch-server-single-user:
	cd server; env FOCALBOARDSERVER_ARGS=--single-user modd

webapp:
	cd webapp; npm run pack

mac-app: server-mac webapp
	rm -rf mac/temp
	rm -rf mac/dist
	rm -rf mac/resources/bin
	rm -rf mac/resources/pack
	mkdir -p mac/resources/bin
	cp bin/mac/focalboard-server mac/resources/bin/focalboard-server
	cp app-config.json mac/resources/config.json
	cp -R webapp/pack mac/resources/pack
	mkdir -p mac/temp
	xcodebuild archive -workspace mac/Focalboard.xcworkspace -scheme Focalboard -archivePath mac/temp/focalboard.xcarchive CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED="NO" CODE_SIGNING_ALLOWED="NO"
	mkdir -p mac/dist
	cp -R mac/temp/focalboard.xcarchive/Products/Applications/Focalboard.app mac/dist/
	# xcodebuild -exportArchive -archivePath mac/temp/focalboard.xcarchive -exportPath mac/dist -exportOptionsPlist mac/export.plist
	cp build/MIT-COMPILED-LICENSE.md mac/dist
	cp NOTICE.txt mac/dist
	cp webapp/NOTICE.txt mac/dist/webapp-NOTICE.txt
	cd mac/dist; zip -r focalboard-mac.zip Focalboard.app MIT-COMPILED-LICENSE.md NOTICE.txt webapp-NOTICE.txt

win-app: server-win webapp
	rm -rf win/temp
	rm -rf win/dist
	cd win; make build
	mkdir -p win/temp
	cp bin/win/focalboard-server.exe win/temp
	cp app-config.json win/temp/config.json
	cp build/MIT-COMPILED-LICENSE.md win/temp
	cp NOTICE.txt win/temp
	cp webapp/NOTICE.txt win/temp/webapp-NOTICE.txt
	cp -R webapp/pack win/temp/pack
	mkdir -p win/dist
	# cd win/temp; tar -acf ../dist/focalboard-win.zip .
	cd win/temp; powershell "Compress-Archive * ../dist/focalboard-win.zip"

linux-app: server-linux webapp
	rm -rf linux/temp
	rm -rf linux/dist
	mkdir -p linux/dist
	mkdir -p linux/temp/focalboard-app
	cp bin/linux/focalboard-server linux/temp/focalboard-app/
	cp app-config.json linux/temp/focalboard-app/config.json
	cp build/MIT-COMPILED-LICENSE.md linux/temp/focalboard-app/
	cp NOTICE.txt linux/temp/focalboard-app/
	cp webapp/NOTICE.txt linux/temp/focalboard-app/webapp-NOTICE.txt
	cp -R webapp/pack linux/temp/focalboard-app/pack
	cd linux; make build
	cp -R linux/bin/focalboard-app linux/temp/focalboard-app/
	cd linux/temp; tar -zcf ../dist/focalboard-linux.tar.gz focalboard-app
	rm -rf linux/temp

clean:
	rm -rf bin
	rm -rf dist
	rm -rf webapp/pack
	rm -rf mac/temp
	rm -rf mac/dist
	rm -rf linux/dist
	rm -rf win/dist

cleanall: clean
	rm -rf webapp/node_modules

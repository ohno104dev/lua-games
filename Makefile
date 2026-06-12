.PHONY: install dev build preview prepare-dist build-games build-top-down-shooter build-shooting-gallery build-lili-run clean

install:
	npm install

dev:
	npm run dev

build:
	npm run build

preview:
	npm run preview

prepare-dist:
	npm run prepare:dist

build-games:
	npm run build:games

build-top-down-shooter:
	npm run build:top-down-shooter

build-shooting-gallery:
	npm run build:shooting-gallery

build-lili-run:
	npm run build:lili-run

clean:
	rm -rf dist public

.PHONY: install dev build preview prepare-dist build-games build-topgun-shooter build-crazy-shotgun build-lili-run clean

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

build-topgun-shooter:
	npm run build:topgun-shooter

build-crazy-shotgun:
	npm run build:crazy-shotgun

build-lili-run:
	npm run build:lili-run

clean:
	rm -rf dist public

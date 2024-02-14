build:
	docker build -f Dockerfile.dev -t fury-little_monster-gem-dev .

rspec:
	docker run -it -v .:/app fury-little_monster-gem-dev bundle exec rspec

rubocop:
	docker run -it -v .:/app fury-little_monster-gem-dev bundle exec rubocop lib spec --format simple

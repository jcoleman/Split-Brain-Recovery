up:
	@docker-compose -f docker-compose.yml up

build:
	@bash -c "docker build -t postgres-splitbrain ."

rm:
	@docker-compose -f docker-compose.yml rm -svf

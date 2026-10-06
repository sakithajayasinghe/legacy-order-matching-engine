IMAGE ?= matcheng-legacy

.PHONY: build run gen docker-build docker-run clean

build:
	mkdir -p bin
	cobc -x -I copybooks -o bin/MATCHENG src/MATCHENG.cbl

run: build
	./run/RUNBATCH.sh

gen:
	python3 tools/gen_orders.py --count 10000 --seed 42 --out data/ORDERS.DAT

docker-build:
	docker build -t $(IMAGE) .

docker-run:
	mkdir -p output
	docker run --rm -v "$(CURDIR)/output:/opt/matcheng/output" $(IMAGE)

clean:
	rm -rf bin output

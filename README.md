# MediaCMS

### Current versions of dependencies

* Bento4: 1.6.0-639
* Python: 3.9.7
* MediaCMS: 1.6

## Build

* Clone original repository:

  ```shell
  git clone https://github.com/mediacms-io/mediacms -b v1.6 /tmp/mediacms-original
  ```

* Compile image

	```bash
	cp Dockerfile /tmp/mediacms-original
	docker build --tag mediacms:1.6 \
		--build-arg "PYTHON_VERSION=3.9.7" \
		--build-arg "BENTO4_VERSION=v1.6.0-639" \
		/tmp/mediacms-original/
	```


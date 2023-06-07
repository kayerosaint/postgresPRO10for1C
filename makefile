SHELL := /bin/bash
# restore conf file
restore:
	rm -rf /var/lib/pgpro/1c-10/data/postgresql.conf && sudo cp postgresql_non-*.conf /var/lib/pgpro/1c-10/data/postgresql.conf
# ignore duplicate names
.PHONY: restore

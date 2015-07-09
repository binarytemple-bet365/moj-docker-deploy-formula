{% if salt['pillar.get']('rds:db-engine', False) == 'postgres' %}
postgresql-client:
  pkg.installed
{% endif %}

{% for branch_name in salt['grains.get']('dead_branch_names', []) %}
{% set branch_name = branch_name | replace("'", "''") %}

{% if salt['pillar.get']('rds:db-engine', False) == 'postgres' %}
'{{ branch_name }}_dropdb':
  cmd.run:
    - name: dropdb --if-exists '{{branch_name}}'
    - env:
      - PGPASSWORD: '{{salt['pillar.get']('rds:db-master-password')}}'
      - PGHOST: '{{salt['grains.get']('dbhost')}}'
      - PGPORT: '{{salt['grains.get']('dbport')}}'
      - PGUSER: '{{salt['pillar.get']('rds:db-master-username')}}'
    - require:
      - docker: '{{ branch_name }}'
      - pkg: postgresql-client
      - cmd: '{{ branch_name }}_dropconnections'

'/tmp/dc-{{branch_name}}.sql':
  file.managed:
    - source: salt://templates/disconnect_postgres.sql
    - template: jinja
    - context:
      branch_name: '{{branch_name}}'

'{{ branch_name }}_dropconnections':
  cmd.run:
    - name: 'psql -d {{salt['pillar.get']('rds:db-name')}} -f /tmp/dc-{{branch_name}}.sql'
    - require:
      - file: '/tmp/dc-{{branch_name}}.sql'
    - env:
      - PGPASSWORD: '{{salt['pillar.get']('rds:db-master-password')}}'
      - PGHOST: '{{salt['grains.get']('dbhost')}}'
      - PGPORT: '{{salt['grains.get']('dbport')}}'
      - PGUSER: '{{salt['pillar.get']('rds:db-master-username')}}'
{% endif %}

'/etc/nginx/conf.d/{{branch_name}}.conf':
  file.absent:
    - watch_in:
      - service: nginx

'{{ branch_name }}':
  docker.absent

'dead_branch_names_{{branch_name}}':
  grains.list_absent:
    - name: dead_branch_names
    - value: '{{ branch_name }}'

{% endfor %}

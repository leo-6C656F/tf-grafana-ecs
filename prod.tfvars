name="tf-grafana-ecs"
env="prod"
team="SRE"
product="SRE"
terraform_prefix="tfg"
description="Created via Terraform"
kmsAlias = "sre/grafana"

whiteListIP = [
		"0.0.0.0/0", #ALL
		]
grafanaPlugins = [
					"grafana-bigquery-datasource",
					"grafana-athena-datasource",
					"grafana-x-ray-datasource,marcusolsson-json-datasource",
					"grafana-clock-panel",
					"volkovlabs-image-panel",
					"michaeldmoore-multistat-panel",
					"natel-plotly-panel",
					"philipsgis-phlowchart-panel",
					"volkovlabs-echarts-panel",
					"volkovlabs-variable-panel",
					"briangann-gauge-panel",
					"jdbranham-diagram-panel",
					"grafana-guidedtour-panel"
				]
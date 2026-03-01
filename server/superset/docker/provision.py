#!/usr/bin/env python3
"""
Superset Provisioning Script.

Автоматически создаёт:
- Database connection (PostgreSQL)
- Datasets (robots, users, pair_codes)
- Charts
- Dashboard "Аналитика роботов"
"""

import logging
import os
import sys
import time

import requests

logging.basicConfig(level=logging.INFO, format="%(asctime)s - %(levelname)s - %(message)s")
logger = logging.getLogger(__name__)

SUPERSET_URL = os.getenv("SUPERSET_URL", "http://localhost:8088")
ADMIN_USERNAME = os.getenv("SUPERSET_ADMIN_USERNAME", "admin")
ADMIN_PASSWORD = os.getenv("SUPERSET_ADMIN_PASSWORD", "admin")

DATABASE_USER = os.getenv("DATABASE_USER", "monitoring")
DATABASE_PASSWORD = os.getenv("DATABASE_PASSWORD", "monitoring")
DATABASE_HOST = os.getenv("DATABASE_HOST", "postgres")
DATABASE_PORT = os.getenv("DATABASE_PORT", "5432")
DATABASE_DB = os.getenv("DATABASE_DB", "monitoring")


class SupersetProvisioner:
    """Provisioner для Superset."""

    def __init__(self):
        self.session = requests.Session()
        self.access_token = None
        self.csrf_token = None
        self.database_id = None
        self.datasets = {}
        self.charts = {}

    def wait_for_superset(self, timeout: int = 120):
        """Ждём готовности Superset."""
        logger.info("Waiting for Superset to be ready...")
        start = time.time()
        while time.time() - start < timeout:
            try:
                resp = self.session.get(f"{SUPERSET_URL}/health", timeout=5)
                if resp.status_code == 200:
                    logger.info("Superset is ready!")
                    return True
            except requests.RequestException:
                pass
            time.sleep(2)
        raise TimeoutError("Superset did not become ready in time")

    def login(self):
        """Получаем JWT токен."""
        logger.info("Logging in to Superset...")
        resp = self.session.post(
            f"{SUPERSET_URL}/api/v1/security/login",
            json={
                "username": ADMIN_USERNAME,
                "password": ADMIN_PASSWORD,
                "provider": "db",
            },
        )
        resp.raise_for_status()
        self.access_token = resp.json()["access_token"]
        self.session.headers["Authorization"] = f"Bearer {self.access_token}"

        # Получаем CSRF токен
        resp = self.session.get(f"{SUPERSET_URL}/api/v1/security/csrf_token/")
        resp.raise_for_status()
        self.csrf_token = resp.json()["result"]
        self.session.headers["X-CSRFToken"] = self.csrf_token
        logger.info("Login successful")

    def get_existing_database(self) -> int | None:
        """Проверяем, есть ли уже подключение к БД."""
        import json

        filters = json.dumps({"filters": [{"col": "database_name", "opr": "eq", "value": "WolfpackCloud PostgreSQL"}]})
        resp = self.session.get(f"{SUPERSET_URL}/api/v1/database/", params={"q": filters})
        resp.raise_for_status()
        databases = resp.json().get("result", [])
        if databases:
            return databases[0]["id"]
        return None

    def create_database(self) -> int:
        """Создаём подключение к PostgreSQL."""
        existing_id = self.get_existing_database()
        if existing_id:
            logger.info(f"Database connection already exists (id={existing_id})")
            return existing_id

        logger.info("Creating PostgreSQL database connection...")
        sqlalchemy_uri = (
            f"postgresql://{DATABASE_USER}:{DATABASE_PASSWORD}"
            f"@{DATABASE_HOST}:{DATABASE_PORT}/{DATABASE_DB}"
        )
        resp = self.session.post(
            f"{SUPERSET_URL}/api/v1/database/",
            json={
                "database_name": "WolfpackCloud PostgreSQL",
                "sqlalchemy_uri": sqlalchemy_uri,
                "expose_in_sqllab": True,
                "allow_run_async": True,
                "allow_ctas": True,
                "allow_cvas": True,
                "allow_dml": False,
                "extra": '{"allows_virtual_table_explore": true}',
            },
        )
        resp.raise_for_status()
        db_id = resp.json()["id"]
        logger.info(f"Database connection created (id={db_id})")
        return db_id

    def get_existing_dataset(self, table_name: str) -> int | None:
        """Проверяем, есть ли уже dataset."""
        import json

        filters = json.dumps({"filters": [{"col": "table_name", "opr": "eq", "value": table_name}]})
        resp = self.session.get(f"{SUPERSET_URL}/api/v1/dataset/", params={"q": filters})
        resp.raise_for_status()
        datasets = resp.json().get("result", [])
        if datasets:
            return datasets[0]["id"]
        return None

    def create_dataset(self, table_name: str, description: str = "") -> int:
        """Создаём dataset."""
        existing_id = self.get_existing_dataset(table_name)
        if existing_id:
            logger.info(f"Dataset '{table_name}' already exists (id={existing_id})")
            return existing_id

        logger.info(f"Creating dataset '{table_name}'...")
        resp = self.session.post(
            f"{SUPERSET_URL}/api/v1/dataset/",
            json={
                "database": self.database_id,
                "schema": "public",
                "table_name": table_name,
            },
        )
        resp.raise_for_status()
        ds_id = resp.json()["id"]
        logger.info(f"Dataset '{table_name}' created (id={ds_id})")
        return ds_id

    def get_existing_chart(self, chart_name: str) -> int | None:
        """Проверяем, есть ли уже chart."""
        import json

        filters = json.dumps({"filters": [{"col": "slice_name", "opr": "eq", "value": chart_name}]})
        resp = self.session.get(f"{SUPERSET_URL}/api/v1/chart/", params={"q": filters})
        resp.raise_for_status()
        charts = resp.json().get("result", [])
        if charts:
            return charts[0]["id"]
        return None

    def create_chart(self, name: str, viz_type: str, dataset_id: int, params: dict) -> int:
        """Создаём chart."""
        existing_id = self.get_existing_chart(name)
        if existing_id:
            logger.info(f"Chart '{name}' already exists (id={existing_id})")
            return existing_id

        logger.info(f"Creating chart '{name}'...")
        resp = self.session.post(
            f"{SUPERSET_URL}/api/v1/chart/",
            json={
                "slice_name": name,
                "viz_type": viz_type,
                "datasource_id": dataset_id,
                "datasource_type": "table",
                "params": str(params).replace("'", '"').replace("True", "true").replace("False", "false").replace("None", "null"),
            },
        )
        resp.raise_for_status()
        chart_id = resp.json()["id"]
        logger.info(f"Chart '{name}' created (id={chart_id})")
        return chart_id

    def get_existing_dashboard(self, dashboard_title: str) -> int | None:
        """Проверяем, есть ли уже dashboard."""
        import json

        filters = json.dumps({"filters": [{"col": "dashboard_title", "opr": "eq", "value": dashboard_title}]})
        resp = self.session.get(f"{SUPERSET_URL}/api/v1/dashboard/", params={"q": filters})
        resp.raise_for_status()
        dashboards = resp.json().get("result", [])
        if dashboards:
            return dashboards[0]["id"]
        return None

    def create_dashboard(self, title: str, chart_ids: list[int]) -> int:
        """Создаём или обновляем dashboard."""
        existing_id = self.get_existing_dashboard(title)
        if existing_id:
            logger.info(f"Dashboard '{title}' already exists (id={existing_id}), updating...")
            self._add_charts_to_dashboard(existing_id, chart_ids)
            return existing_id

        logger.info(f"Creating dashboard '{title}'...")

        position_json = self._build_dashboard_layout(chart_ids)

        resp = self.session.post(
            f"{SUPERSET_URL}/api/v1/dashboard/",
            json={
                "dashboard_title": title,
                "slug": "robots-analytics",
                "position_json": position_json,
                "published": True,
            },
        )
        resp.raise_for_status()
        dashboard_id = resp.json()["id"]

        self._add_charts_to_dashboard(dashboard_id, chart_ids)

        logger.info(f"Dashboard '{title}' created (id={dashboard_id})")
        return dashboard_id

    def _build_dashboard_layout(self, chart_ids: list[int]) -> str:
        """Создаём JSON layout для дашборда."""
        import json

        layout = {
            "DASHBOARD_VERSION_KEY": "v2",
            "ROOT_ID": {"type": "ROOT", "id": "ROOT_ID", "children": ["GRID_ID"]},
            "GRID_ID": {
                "type": "GRID",
                "id": "GRID_ID",
                "children": [],
                "parents": ["ROOT_ID"],
            },
            "HEADER_ID": {
                "id": "HEADER_ID",
                "type": "HEADER",
                "meta": {"text": "Аналитика роботов"},
            },
        }

        # Добавляем row для каждой пары charts
        row_idx = 0
        for i in range(0, len(chart_ids), 2):
            row_id = f"ROW-{row_idx}"
            layout["GRID_ID"]["children"].append(row_id)

            row_children = []
            for j, chart_id in enumerate(chart_ids[i : i + 2]):
                chart_component_id = f"CHART-{chart_id}"
                row_children.append(chart_component_id)
                layout[chart_component_id] = {
                    "type": "CHART",
                    "id": chart_component_id,
                    "children": [],
                    "parents": ["ROOT_ID", "GRID_ID", row_id],
                    "meta": {
                        "width": 6,
                        "height": 50,
                        "chartId": chart_id,
                    },
                }

            layout[row_id] = {
                "type": "ROW",
                "id": row_id,
                "children": row_children,
                "parents": ["ROOT_ID", "GRID_ID"],
                "meta": {"background": "BACKGROUND_TRANSPARENT"},
            }
            row_idx += 1

        return json.dumps(layout)

    def _add_charts_to_dashboard(self, dashboard_id: int, chart_ids: list[int]):
        """Привязываем charts к dashboard через update position_json и slices."""
        import json

        position_json = self._build_dashboard_layout(chart_ids)
        json_metadata = json.dumps({
            "chart_configuration": {},
            "native_filter_configuration": [],
            "timed_refresh_immune_slices": [],
            "expanded_slices": {},
            "refresh_frequency": 0,
            "color_scheme": "",
            "label_colors": {},
            "shared_label_colors": {},
            "default_filters": "{}",
        })

        resp = self.session.get(f"{SUPERSET_URL}/api/v1/dashboard/{dashboard_id}")
        if resp.status_code == 200:
            current_slices = [s["id"] for s in resp.json().get("result", {}).get("slices", [])]
            new_slices = [cid for cid in chart_ids if cid not in current_slices]
            all_slices = list(set(current_slices + chart_ids))
        else:
            all_slices = chart_ids

        resp = self.session.put(
            f"{SUPERSET_URL}/api/v1/dashboard/{dashboard_id}",
            json={
                "position_json": position_json,
                "json_metadata": json_metadata,
            },
        )
        if resp.status_code not in (200, 201):
            logger.warning(f"Could not update dashboard layout: {resp.text}")

        for chart_id in all_slices:
            self._link_chart_to_dashboard(dashboard_id, chart_id)

    def _link_chart_to_dashboard(self, dashboard_id: int, chart_id: int):
        """Связываем chart с dashboard через API chart update."""
        resp = self.session.get(f"{SUPERSET_URL}/api/v1/chart/{chart_id}")
        if resp.status_code != 200:
            return

        chart_data = resp.json().get("result", {})
        current_dashboards = [d["id"] for d in chart_data.get("dashboards", [])]
        if dashboard_id in current_dashboards:
            return

        resp = self.session.put(
            f"{SUPERSET_URL}/api/v1/chart/{chart_id}",
            json={"dashboards": current_dashboards + [dashboard_id]},
        )
        if resp.status_code not in (200, 201):
            logger.warning(f"Could not link chart {chart_id} to dashboard: {resp.text}")

    def provision(self):
        """Основной процесс provisioning."""
        try:
            self.wait_for_superset()
            self.login()

            # 1. Создаём подключение к БД
            self.database_id = self.create_database()

            # 2. Создаём datasets
            self.datasets["robots"] = self.create_dataset("robots", "Таблица роботов")
            self.datasets["users"] = self.create_dataset("users", "Таблица пользователей")
            self.datasets["pair_codes"] = self.create_dataset("pair_codes", "Коды привязки")

            # 3. Создаём charts
            # Chart 1: Количество роботов по статусу (Pie)
            self.charts["robots_by_status"] = self.create_chart(
                name="Роботы по статусу",
                viz_type="pie",
                dataset_id=self.datasets["robots"],
                params={
                    "groupby": ["status"],
                    "metric": {"expressionType": "SIMPLE", "column": {"column_name": "id"}, "aggregate": "COUNT"},
                    "row_limit": 100,
                    "color_scheme": "supersetColors",
                    "show_labels": True,
                    "show_legend": True,
                },
            )

            # Chart 2: Роботы по архитектуре (Bar)
            self.charts["robots_by_arch"] = self.create_chart(
                name="Роботы по архитектуре",
                viz_type="dist_bar",
                dataset_id=self.datasets["robots"],
                params={
                    "groupby": ["architecture"],
                    "metrics": [{"expressionType": "SIMPLE", "column": {"column_name": "id"}, "aggregate": "COUNT"}],
                    "row_limit": 100,
                    "color_scheme": "supersetColors",
                    "show_legend": True,
                    "y_axis_format": "SMART_NUMBER",
                },
            )

            # Chart 3: Регистрации роботов по времени (Time Series)
            self.charts["robots_over_time"] = self.create_chart(
                name="Регистрации роботов",
                viz_type="echarts_timeseries_line",
                dataset_id=self.datasets["robots"],
                params={
                    "x_axis": "created_at",
                    "time_grain_sqla": "P1D",
                    "metrics": [{"expressionType": "SIMPLE", "column": {"column_name": "id"}, "aggregate": "COUNT"}],
                    "row_limit": 1000,
                    "color_scheme": "supersetColors",
                },
            )

            # Chart 4: Таблица роботов
            self.charts["robots_table"] = self.create_chart(
                name="Список роботов",
                viz_type="table",
                dataset_id=self.datasets["robots"],
                params={
                    "groupby": ["id", "name", "hostname", "status", "architecture", "created_at", "last_seen_at"],
                    "row_limit": 100,
                    "include_time": False,
                    "order_desc": True,
                },
            )

            # Chart 5: Количество пользователей
            self.charts["users_count"] = self.create_chart(
                name="Всего пользователей",
                viz_type="big_number_total",
                dataset_id=self.datasets["users"],
                params={
                    "metric": {"expressionType": "SIMPLE", "column": {"column_name": "id"}, "aggregate": "COUNT"},
                    "subheader": "зарегистрировано",
                },
            )

            # Chart 6: Активные коды привязки
            self.charts["pending_codes"] = self.create_chart(
                name="Ожидающие привязки",
                viz_type="big_number_total",
                dataset_id=self.datasets["pair_codes"],
                params={
                    "metric": {"expressionType": "SIMPLE", "column": {"column_name": "id"}, "aggregate": "COUNT"},
                    "adhoc_filters": [
                        {
                            "expressionType": "SIMPLE",
                            "clause": "WHERE",
                            "subject": "status",
                            "operator": "==",
                            "comparator": "pending",
                        }
                    ],
                    "subheader": "кодов",
                },
            )

            # 4. Создаём dashboard
            chart_ids = list(self.charts.values())
            self.create_dashboard("Аналитика роботов", chart_ids)

            logger.info("Provisioning completed successfully!")
            return True

        except Exception as e:
            logger.error(f"Provisioning failed: {e}")
            return False


def main():
    provisioner = SupersetProvisioner()
    success = provisioner.provision()
    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()

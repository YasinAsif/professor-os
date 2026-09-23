"""Re-export of app.services.clo_attainment to support root-level services imports."""

from app.services.clo_attainment import (
    CLOAttainmentMetric,
    CourseAttainmentReport,
    compute_and_record_attainment,
    calculate_clo_attainment_task,
)

__all__ = [
    "CLOAttainmentMetric",
    "CourseAttainmentReport",
    "compute_and_record_attainment",
    "calculate_clo_attainment_task",
]

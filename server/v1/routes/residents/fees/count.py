from __future__ import annotations

from datetime import datetime, timezone
from typing import Annotated, List, Optional

from fastapi import Depends, Query, Response, status

from ....app import api_v1
from ....models import Fee, PaymentStatus, Resident, Result
from .....config import EPOCH


__all__ = ("residents_fees_count",)


@api_v1.get(
    "/residents/fees/count",
    name="Fee counting",
    description="Count the number of fees related to the current resident",
    tags=["resident"],
    responses={
        status.HTTP_200_OK: {
            "description": "The operation completed successfully",
            "model": Result[List[Fee]],
        },
        status.HTTP_400_BAD_REQUEST: {
            "description": "Incorrect authorization data",
            "model": Result[None],
        },
    },
)
async def residents_fees_count(
    resident: Annotated[Result[Optional[Resident]], Depends(Resident.from_token)],
    response: Response,
    *,
    paid: Annotated[Optional[bool], Query(description="Whether to count paid or unpaid queries only")] = None,
    created_after: Annotated[
        datetime,
        Query(description="Count fees created after this timestamp"),
    ] = EPOCH,
    created_before: Annotated[
        datetime,
        Query(
            description="Count fees created before this timestamp",
            default_factory=lambda: datetime.now(timezone.utc),
        ),
    ],
) -> Result[Optional[int]]:
    if resident.data is None:
        response.status_code = status.HTTP_400_BAD_REQUEST
        return Result(code=402, data=None)

    return await PaymentStatus.count(
        resident.data.room,
        paid=paid,
        created_after=created_after,
        created_before=created_before,
    )

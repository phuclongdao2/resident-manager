from __future__ import annotations

from fastapi import status

from ......apps import api_v1
from ......database import Database
from ......errors import AuthenticationRequired, PasswordDecryptionError, register_error
from ......models import AuthorizationHeader, Resident


__all__ = ("admin_residents_count",)


@api_v1.get(
    "/admin/residents/count",
    name="Registration requests count",
    description="Return number of registration requests",
    tags=["admin"],
    responses=register_error(AuthenticationRequired, PasswordDecryptionError),
    status_code=status.HTTP_200_OK,
)
async def admin_residents_count(headers: AuthorizationHeader) -> int:
    await Database.instance.verify_admin(headers.username, headers.decrypt_password())
    return await Resident.count()

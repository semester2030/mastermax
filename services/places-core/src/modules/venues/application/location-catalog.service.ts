import { Injectable } from "@nestjs/common";
import { PgService } from "../../../shared/database/pg.service";
import { AppError } from "../../../shared/errors/app-error";
import { ErrorCodes } from "../../../shared/errors/error-codes";

export type LocationCity = {
  id: string;
  code: string;
  nameAr: string;
  nameEn: string;
};

export type LocationDistrict = {
  id: string;
  cityId: string;
  code: string;
  nameAr: string;
  nameEn: string;
};

@Injectable()
export class LocationCatalogService {
  constructor(private readonly pg: PgService) {}

  async listCities(): Promise<LocationCity[]> {
    const res = await this.pg.query<{
      id: string;
      code: string;
      name_ar: string;
      name_en: string;
    }>(
      `SELECT id, code, name_ar, name_en
       FROM places_cities WHERE status = 'active'
       ORDER BY sort_order, name_ar`,
    );
    return res.rows.map((r) => ({
      id: r.id,
      code: r.code,
      nameAr: r.name_ar,
      nameEn: r.name_en,
    }));
  }

  async listDistricts(cityId: string): Promise<LocationDistrict[]> {
    const city = await this.pg.query(`SELECT 1 FROM places_cities WHERE id = $1`, [
      cityId,
    ]);
    if (!city.rowCount) {
      throw new AppError(ErrorCodes.NOT_FOUND, "City not found");
    }
    const res = await this.pg.query<{
      id: string;
      city_id: string;
      code: string;
      name_ar: string;
      name_en: string;
    }>(
      `SELECT id, city_id, code, name_ar, name_en
       FROM places_districts
       WHERE city_id = $1 AND status = 'active'
       ORDER BY sort_order, name_ar`,
      [cityId],
    );
    return res.rows.map((r) => ({
      id: r.id,
      cityId: r.city_id,
      code: r.code,
      nameAr: r.name_ar,
      nameEn: r.name_en,
    }));
  }

  async resolveNames(input: {
    cityId?: string | null;
    districtId?: string | null;
  }): Promise<{ city: string | null; district: string | null }> {
    let city: string | null = null;
    let district: string | null = null;
    if (input.cityId) {
      const c = await this.pg.query<{ name_ar: string }>(
        `SELECT name_ar FROM places_cities WHERE id = $1 AND status = 'active'`,
        [input.cityId],
      );
      if (!c.rowCount) {
        throw new AppError(ErrorCodes.VALIDATION_ERROR, "cityId is not a catalog city");
      }
      city = c.rows[0].name_ar;
    }
    if (input.districtId) {
      if (!input.cityId) {
        throw new AppError(ErrorCodes.VALIDATION_ERROR, "districtId requires cityId");
      }
      const d = await this.pg.query<{ name_ar: string }>(
        `SELECT name_ar FROM places_districts
         WHERE id = $1 AND city_id = $2 AND status = 'active'`,
        [input.districtId, input.cityId],
      );
      if (!d.rowCount) {
        throw new AppError(
          ErrorCodes.VALIDATION_ERROR,
          "districtId does not belong to cityId",
        );
      }
      district = d.rows[0].name_ar;
    }
    return { city, district };
  }
}

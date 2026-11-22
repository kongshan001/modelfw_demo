import { describe, expect, it } from "@jest/globals";

import {
  buildSearchQuery,
  normalizeProduct,
  productSchema,
  validateProductFields
} from "../validation";

const SONY = {
  brand: "Sony",
  model: "WH-1000XM5",
  category: "头戴式降噪耳机",
  specs: "蓝牙 5.2 · 约 30 小时续航"
};

describe("product validation", () => {
  it("trims whitespace while keeping all fields", () => {
    const parsed = productSchema.parse({
      brand: "  Sony ",
      model: " WH-1000XM5  ",
      category: " 头戴式降噪耳机 ",
      specs: "  蓝牙 5.2 "
    });
    expect(parsed).toEqual({
      brand: "Sony",
      model: "WH-1000XM5",
      category: "头戴式降噪耳机",
      specs: "蓝牙 5.2"
    });
  });

  it("requires at least a brand or a model", () => {
    const parsed = productSchema.safeParse({
      brand: "",
      model: "  ",
      category: "耳机",
      specs: ""
    });
    expect(parsed.success).toBe(false);
    expect(validateProductFields({
      brand: "",
      model: "",
      category: "",
      specs: ""
    }).brand).toContain("品牌或型号");
  });

  it("rejects overlong model strings", () => {
    const errors = validateProductFields({
      ...SONY,
      model: "X".repeat(121)
    });
    expect(errors.model).toContain("120");
  });

  it("collapses internal whitespace", () => {
    expect(
      normalizeProduct({
        brand: "Anker   安克",
        model: "Nano   II 65W",
        category: "充电器",
        specs: ""
      })
    ).toMatchObject({ brand: "Anker 安克", model: "Nano II 65W" });
  });
});

describe("buildSearchQuery", () => {
  it("builds brand + model + category + price", () => {
    expect(buildSearchQuery(SONY)).toBe(
      "Sony WH-1000XM5 头戴式降噪耳机 价格"
    );
  });

  it("deduplicates repeated parts case-insensitively", () => {
    expect(
      buildSearchQuery({
        brand: "Sony",
        model: "Sony",
        category: "价格",
        specs: ""
      })
    ).toBe("Sony 价格");
  });

  it("handles partial manual input without fake padding", () => {
    expect(
      buildSearchQuery({ brand: "Sony", model: "", category: "", specs: "" })
    ).toBe("Sony 价格");
  });
});

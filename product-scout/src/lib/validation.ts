import { z } from "zod";

import type { ProductIdentity } from "./types";

const compact = (value: string) => value.replace(/\s+/g, " ").trim();

export function normalizeProduct(input: ProductIdentity): ProductIdentity {
  return {
    brand: compact(input.brand).slice(0, 80),
    model: compact(input.model).slice(0, 120),
    category: compact(input.category).slice(0, 80),
    specs: compact(input.specs).slice(0, 240)
  };
}

export const productSchema = z
  .object({
    brand: z.string().trim().max(80, "品牌最多 80 个字符"),
    model: z.string().trim().max(120, "型号最多 120 个字符"),
    category: z.string().trim().max(80, "品类最多 80 个字符"),
    specs: z.string().trim().max(240, "关键规格最多 240 个字符")
  })
  .superRefine((value, ctx) => {
    if (!compact(value.brand) && !compact(value.model)) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        message: "请至少填写品牌或型号，才能构造检索词",
        path: ["brand"]
      });
    }
  })
  .transform(normalizeProduct);

export const searchRequestSchema = z.object({
  product: productSchema
});

export const imageDataUrlSchema = z
  .string()
  .max(12_000_000, "图片过大，最大 8MB")
  .regex(
    /^data:image\/(?:png|jpeg|webp);base64,[A-Za-z0-9+/=]+$/,
    "仅支持 PNG / JPEG / WebP 图片"
  );

export const extractRequestSchema = z.object({
  imageDataUrl: imageDataUrlSchema
});

export type FieldValidationErrors = Partial<Record<keyof ProductIdentity, string>>;

export function validateProductFields(
  product: ProductIdentity
): FieldValidationErrors {
  const result = productSchema.safeParse(product);
  if (result.success) return {};

  const errors: FieldValidationErrors = {};
  for (const issue of result.error.issues) {
    const key = issue.path[0];
    if (
      key === "brand" ||
      key === "model" ||
      key === "category" ||
      key === "specs"
    ) {
      errors[key] = errors[key] ?? issue.message;
    }
  }
  return errors;
}

/**
 * Builds the only query we send to a search provider. It is deliberately
 * transparent in the UI so the user can see exactly what was searched.
 */
export function buildSearchQuery(product: ProductIdentity): string {
  const normalized = normalizeProduct(product);
  const parts = [
    normalized.brand,
    normalized.model,
    normalized.category,
    "价格"
  ].filter(Boolean);

  const seen = new Set<string>();
  const unique = parts.filter((part) => {
    const key = part.toLocaleLowerCase();
    if (seen.has(key)) return false;
    seen.add(key);
    return true;
  });

  return unique.join(" ").replace(/\s+/g, " ").trim();
}

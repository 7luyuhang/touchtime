import { useId, type ComponentPropsWithoutRef, type ReactNode } from "react";
import { cx } from "@/lib/cx";

export type InputSize = "sm" | "md" | "lg";

const sizes: Record<InputSize, string> = {
  sm: "h-control-sm text-body-sm",
  md: "h-control-md text-body-sm",
  lg: "h-control-lg text-body-md",
};

export interface InputProps extends Omit<ComponentPropsWithoutRef<"input">, "size"> {
  size?: InputSize;
  label?: ReactNode;
  hint?: ReactNode;
  error?: ReactNode;
}

/** DESIGN.md `form-input` (sm 32 / md 40 / lg 48): hairline border, 6px radius. */
export function Input({ size = "md", label, hint, error, id, className, ...props }: InputProps) {
  const generatedId = useId();
  const inputId = id ?? generatedId;
  const messageId = `${inputId}-message`;
  const message = error ?? hint;

  return (
    <div className={cx("flex flex-col gap-xs", className)}>
      {label && (
        <label htmlFor={inputId} className="text-body-sm-strong text-ink">
          {label}
        </label>
      )}
      <input
        id={inputId}
        aria-invalid={error ? true : undefined}
        aria-describedby={message ? messageId : undefined}
        className={cx(
          "w-full rounded-sm border border-hairline bg-canvas px-sm text-ink transition-colors",
          "placeholder:text-mute hover:border-hairline-strong focus-visible:border-ink focus-visible:outline-none",
          "disabled:cursor-not-allowed disabled:bg-canvas-soft-2 disabled:text-mute",
          "aria-invalid:border-error aria-invalid:focus-visible:border-error",
          sizes[size],
        )}
        {...props}
      />
      {message && (
        <p id={messageId} className={cx("text-caption", error ? "text-error" : "text-mute")}>
          {message}
        </p>
      )}
    </div>
  );
}

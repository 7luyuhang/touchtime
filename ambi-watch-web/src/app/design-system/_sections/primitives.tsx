import { DemoRow, DocGroup, DocSection } from "@/components/docs/docs";
import {
  Badge,
  Banner,
  Button,
  Card,
  Code,
  CodeBlock,
  Heading,
  Icon,
  IconButton,
  Input,
  Separator,
  Tabs,
  Text,
  TextLink,
  type BadgeVariant,
  type ButtonSize,
  type ButtonVariant,
  type IconButtonSize,
  type IconButtonVariant,
} from "@/components/primitives";

const buttonVariants: ButtonVariant[] = ["primary", "secondary", "ghost", "danger"];
const buttonSizes: ButtonSize[] = ["xs", "sm", "md", "lg"];
const iconButtonVariants: IconButtonVariant[] = ["secondary", "primary", "ghost"];
const iconButtonSizes: IconButtonSize[] = ["xs", "sm", "md", "lg"];
const badgeVariants: BadgeVariant[] = ["secondary", "inverted", "info", "warning", "error", "violet", "cyan"];

export function PrimitivesSection() {
  return (
    <DocSection
      id="primitives"
      layer="Primitives · base controls"
      title="Base controls."
      description="Built only from tokens, following the DESIGN.md component specs. Watch-specific components compose these."
    >
      <DocGroup title="Button · pill (marketing scale)">
        {buttonVariants.map((variant) => (
          <DemoRow key={variant} label={variant}>
            {buttonSizes.map((size) => (
              <Button key={size} variant={variant} size={size}>
                {size === "lg" ? "Get started" : "Continue"}
              </Button>
            ))}
          </DemoRow>
        ))}
      </DocGroup>

      <DocGroup title="Button · rounded (in-app / nav scale)">
        <DemoRow label="shape=rounded">
          <Button shape="rounded" size="xs">
            Sign up
          </Button>
          <Button shape="rounded" size="xs" variant="secondary">
            Log in
          </Button>
          <Button shape="rounded" size="sm" variant="secondary" trailing={<Icon name="arrow-right" />}>
            Next
          </Button>
          <Button shape="rounded" size="md" leading={<Icon name="plus" />}>
            Add item
          </Button>
          <Button shape="rounded" size="md" disabled>
            Disabled
          </Button>
        </DemoRow>
      </DocGroup>

      <DocGroup title="IconButton · circular">
        {iconButtonVariants.map((variant) => (
          <DemoRow key={variant} label={variant}>
            {iconButtonSizes.map((size) => (
              <IconButton key={size} variant={variant} size={size} label="Add" icon={<Icon name="plus" />} />
            ))}
          </DemoRow>
        ))}
      </DocGroup>

      <DocGroup title="Tabs · tab-ghost">
        <Tabs
          label="Example tabs"
          items={[
            { value: "overview", label: "Overview", content: <Text size="sm">Overview panel.</Text> },
            { value: "faces", label: "Faces", content: <Text size="sm">Faces panel.</Text> },
            { value: "settings", label: "Settings", content: <Text size="sm">Settings panel.</Text> },
          ]}
        />
      </DocGroup>

      <DocGroup title="Input · form-input">
        <div className="grid max-w-[960px] gap-lg tablet:grid-cols-3">
          <Input size="sm" label="Small (32)" placeholder="Placeholder" />
          <Input size="md" label="Default (40)" placeholder="Placeholder" hint="Helper text in caption." />
          <Input size="lg" label="Large (48)" placeholder="Placeholder" />
          <Input label="Invalid" defaultValue="ambi" error="Validation message." />
          <Input label="Disabled" placeholder="Unavailable" disabled />
        </div>
      </DocGroup>

      <DocGroup title="Badge and banner">
        <DemoRow label="badge">
          {badgeVariants.map((variant) => (
            <Badge key={variant} variant={variant}>
              {variant}
            </Badge>
          ))}
          <Badge mono>MONO</Badge>
        </DemoRow>
        <DemoRow label="banner-marketing">
          <Banner>
            <Badge variant="info">New</Badge>
            Introducing the ambi watch design system
            <Icon name="arrow-right" />
          </Banner>
        </DemoRow>
      </DocGroup>

      <DocGroup title="Card">
        <div className="grid gap-lg tablet:grid-cols-2 desktop:grid-cols-3">
          <Card variant="marketing">
            <CardSample name="marketing" />
          </Card>
          <Card variant="large">
            <CardSample name="large" />
          </Card>
          <Card variant="soft">
            <CardSample name="soft" />
          </Card>
          <Card variant="template">
            <div className="mb-md aspect-video rounded-sm bg-canvas-soft-2" />
            <CardSample name="template" />
          </Card>
          <Card variant="featured">
            <CardSample name="featured" inverted />
          </Card>
        </div>
      </DocGroup>

      <DocGroup title="Text, link and code">
        <div className="flex max-w-[720px] flex-col gap-md">
          <Text>
            Body copy with an <TextLink href="/design-system">inline link</TextLink> and inline{" "}
            <Code>--watch-face-width</Code>.
          </Text>
          <Separator />
          <CodeBlock>{`import { Button } from "@/components/primitives";\n\n<Button variant="primary">Continue</Button>`}</CodeBlock>
        </div>
      </DocGroup>
    </DocSection>
  );
}

function CardSample({ name, inverted = false }: { name: string; inverted?: boolean }) {
  return (
    <div className="flex flex-col gap-xs">
      <Heading as="h3" size="sm">
        {name}
      </Heading>
      <Text size="sm" tone={inverted ? "inherit" : "body"} className={inverted ? "opacity-80" : undefined}>
        Tight heading and body stack, wider gap before any action.
      </Text>
    </div>
  );
}

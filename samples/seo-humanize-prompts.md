# Screenshot Demo Prompts

Use `samples/seo-products.csv` for a cleaner screenshot of Quixote generating ecommerce SEO content.

## Prompt 1: Humanized SEO Description

```text
Rewrite this ecommerce product description so it sounds human, specific, and useful.

Product: {{title}}
Brand: {{brand}}
Category: {{category}}
Audience: {{audience}}
Materials: {{materials}}
Color: {{color}}
Current description: {{current_description}}
SEO keyword: {{seo_keyword}}
Voice notes: {{voice_notes}}

Write 2 short paragraphs. Keep it under 90 words. Use the SEO keyword naturally once. Avoid hype, cliches, and fake claims.
```

## Prompt 2: SEO Title

```text
Create a search-friendly product title for:

Product: {{title}}
Brand: {{brand}}
Type: {{type}}
Color: {{color}}
SEO keyword: {{seo_keyword}}

Return one title under 62 characters. Make it clear, human, and not keyword-stuffed.
```

## Prompt 3: Meta Description

```text
Write a meta description for:

Product: {{title}}
Brand: {{brand}}
Audience: {{audience}}
Current description: {{current_description}}
SEO keyword: {{seo_keyword}}

Return one sentence under 155 characters. Mention a concrete product detail.
```

## Suggested Screenshot Models

```text
OpenAI: gpt-4.1, gpt-4.1-mini, gpt-5-mini
Gemini: gemini-2.5-flash, gemini-2.5-pro
Ollama: llama3.2, qwen2.5, mistral
LM Studio: google/gemma-4-26b-a4b, meta-llama/llama-3.1-8b-instruct
Custom OpenAI-compatible: any model exposed by your gateway
```

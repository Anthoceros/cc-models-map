<h1 align="center">cc-models-map</h1>

<p align="center">Point each Claude Code tier alias (opus / sonnet / haiku / fable / smallfast) at a real model served by your local Claude Code Router (CCR) gateway.</p>

<p align="center">
  <a href="./README.md">English</a> | <a href="./README.zh-CN.md">简体中文</a>
</p>

## Prerequisites

- Claude Code installed.
- [Claude Code Router](https://github.com/musistudio/claude-code-router) (CCR) installed and running on this machine.

## What you can do

- Map any tier to a model, for example "Map the sonnet tier to MiniMax (China)/MiniMax-M3".
- See what each of the five tiers currently points at.
- List the models your gateway can route to.
- Restart CCR and confirm a tier's route actually answers.

## How it fits together

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="./assets/architecture-dark.svg">
  <img alt="Configuration flow from tier.sh through CCR's config.sqlite, the regenerated wrapper, a new claude session, and the CCR gateway to the upstream provider" src="./assets/architecture.svg">
</picture>

[`tier.sh`](./tier.sh) writes a single tier field into CCR's `config.sqlite`; restarting CCR regenerates the wrapper so it exports `ANTHROPIC_DEFAULT_<TIER>_MODEL` for every tier. A new `claude --model <tier>` session captures that env var at process start and sends `/v1/messages` to the CCR gateway at `127.0.0.1:3456`, which then routes the call to the upstream `Provider/model` target.

## Install

Paste this into your agent:

> Install the skill at https://github.com/Anthoceros/cc-models-map.git — put `SKILL.md` and `tier.sh` into `~/.claude/skills/cc-models-map/` and make `tier.sh` executable. Report the result; do not run any of its commands yet.

## Usage

Paste this into your agent:

> Map the sonnet tier to MiniMax (China)/MiniMax-M3

It updates the mapping, restarts CCR, and runs a real session to confirm the route works.

## Notes

- A mapping only applies to newly started Claude Code sessions. Open a new session to use it.
- The model must be written as `Provider/model`, using the provider's display name as CCR shows it (for example `MiniMax (China)`). A bare Claude alias such as `claude-opus-4-5` is rejected.
- If your default tier starts failing after a change, `~/.claude/settings.json` may still hold an `ANTHROPIC_MODEL` pointing at a provider you removed. Clear it, or pick an explicit tier.

#!/usr/bin/env node
import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import {
  ListToolsRequestSchema,
  CallToolRequestSchema,
  ErrorCode,
  McpError,
} from "@modelcontextprotocol/sdk/types.js";
import path from "path";
import { fileURLToPath } from "url";
import dotenv from "dotenv";
import { z } from "zod";
import { zodToJsonSchema } from "zod-to-json-schema";
import { callGPT5, callGPT5WithMessages } from "./utils.js";

// Initialize environment from parent directory
import { dirname } from "path";
const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
const envPath = path.join(__dirname, "../../.env");
dotenv.config({ path: envPath });
console.error("Environment loaded from:", envPath);

// Schema definitions
const GPT5GenerateSchema = z.object({
  input: z.string().describe("The input text or prompt for GPT-5"),
  model: z
    .string()
    .optional()
    .default("gpt-5")
    .describe("GPT-5 model variant to use"),
  instructions: z
    .string()
    .optional()
    .describe("System instructions for the model"),
  reasoning_effort: z
    .enum(["low", "medium", "high"])
    .optional()
    .describe("Reasoning effort level"),
});

const GPT5MessagesSchema = z.object({
  messages: z
    .array(
      z.object({
        role: z
          .enum(["user", "developer", "assistant"])
          .describe("Message role"),
        content: z.string().describe("Message content"),
      }),
    )
    .describe("Array of conversation messages"),
  model: z
    .string()
    .optional()
    .default("gpt-5")
    .describe("GPT-5 model variant to use"),
  instructions: z
    .string()
    .optional()
    .describe("System instructions for the model"),
  reasoning_effort: z
    .enum(["low", "medium", "high"])
    .optional()
    .describe("Reasoning effort level"),
});

// Type definitions
type GPT5GenerateArgs = z.infer<typeof GPT5GenerateSchema>;
type GPT5MessagesArgs = z.infer<typeof GPT5MessagesSchema>;

// Main function
async function main() {
  // Check if OPENAI_API_KEY is set
  if (!process.env.OPENAI_API_KEY) {
    console.error("Error: OPENAI_API_KEY environment variable is not set");
    console.error("Please set it in .env file or as an environment variable");
    process.exit(1);
  }

  // Create MCP server
  const server = new Server(
    {
      name: "gpt5-mcp-server",
      version: "0.1.0",
    },
    {
      capabilities: {
        tools: {},
      },
    },
  );

  // Set up error handling
  server.onerror = (error) => {
    console.error("MCP Server Error:", error);
  };

  process.on("SIGINT", async () => {
    await server.close();
    process.exit(0);
  });

  // Set up tool handlers
  server.setRequestHandler(ListToolsRequestSchema, async () => {
    console.error("Handling ListToolsRequest");
    return {
      tools: [
        {
          name: "gpt5_generate",
          description:
            "Generate text using OpenAI GPT-5 API with a simple input prompt",
          inputSchema: zodToJsonSchema(GPT5GenerateSchema),
        },
        {
          name: "gpt5_messages",
          description:
            "Generate text using GPT-5 with structured conversation messages",
          inputSchema: zodToJsonSchema(GPT5MessagesSchema),
        },
      ],
    };
  });

  server.setRequestHandler(CallToolRequestSchema, async (request) => {
    console.error("Handling CallToolRequest:", JSON.stringify(request.params));

    try {
      switch (request.params.name) {
        case "gpt5_generate": {
          const args = GPT5GenerateSchema.parse(
            request.params.arguments,
          ) as GPT5GenerateArgs;
          console.error(`GPT-5 Generate: "${args.input.substring(0, 100)}..."`);

          const result = await callGPT5(
            process.env.OPENAI_API_KEY!,
            args.input,
            {
              model: args.model,
              instructions: args.instructions,
              reasoning_effort: args.reasoning_effort,
            },
          );

          let responseText = result.content;
          if (result.usage) {
            const usage = result.usage;
            responseText += `\n\n**Usage:**\n`;
            responseText += `- Prompt tokens: ${usage.prompt_tokens}\n`;
            responseText += `- Completion tokens: ${usage.completion_tokens}\n`;
            responseText += `- Total tokens: ${usage.total_tokens}`;
            if (usage.reasoning_tokens) {
              responseText += `\n- Reasoning tokens: ${usage.reasoning_tokens}`;
            }
          }

          return {
            content: [
              {
                type: "text",
                text: responseText,
              },
            ],
          };
        }

        case "gpt5_messages": {
          const args = GPT5MessagesSchema.parse(
            request.params.arguments,
          ) as GPT5MessagesArgs;
          console.error(`GPT-5 Messages: ${args.messages.length} messages`);

          const result = await callGPT5WithMessages(
            process.env.OPENAI_API_KEY!,
            args.messages,
            {
              model: args.model,
              instructions: args.instructions,
              reasoning_effort: args.reasoning_effort,
            },
          );

          let responseText = result.content;
          if (result.usage) {
            const usage = result.usage;
            responseText += `\n\n**Usage:**\n`;
            responseText += `- Prompt tokens: ${usage.prompt_tokens}\n`;
            responseText += `- Completion tokens: ${usage.completion_tokens}\n`;
            responseText += `- Total tokens: ${usage.total_tokens}`;
            if (usage.reasoning_tokens) {
              responseText += `\n- Reasoning tokens: ${usage.reasoning_tokens}`;
            }
          }

          return {
            content: [
              {
                type: "text",
                text: responseText,
              },
            ],
          };
        }

        default:
          throw new McpError(
            ErrorCode.MethodNotFound,
            `Unknown tool: ${request.params.name}`,
          );
      }
    } catch (error) {
      console.error("ERROR during GPT-5 API call:", error);

      return {
        content: [
          {
            type: "text",
            text: `GPT-5 API error: ${error instanceof Error ? error.message : String(error)}`,
          },
        ],
        isError: true,
      };
    }
  });

  // Start the server
  console.error("Starting GPT-5 MCP server");

  try {
    const transport = new StdioServerTransport();
    console.error("StdioServerTransport created");

    await server.connect(transport);
    console.error("Server connected to transport");

    console.error("GPT-5 MCP server running on stdio");
  } catch (error) {
    console.error("ERROR starting server:", error);
    throw error;
  }
}

// Main execution
main().catch((error) => {
  console.error("Server runtime error:", error);
  process.exit(1);
});


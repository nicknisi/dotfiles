import fetch from 'node-fetch';

interface GPT5Message {
  role: 'user' | 'developer' | 'assistant';
  content: string;
}

interface GPT5Request {
  model: string;
  messages: GPT5Message[];
  reasoning_effort?: 'low' | 'medium' | 'high';
}

interface GPT5Response {
  id: string;
  object: string;
  created: number;
  model: string;
  choices: Array<{
    index: number;
    message: {
      role: string;
      content: string;
      refusal?: string | null;
    };
    finish_reason: string;
  }>;
  usage?: {
    prompt_tokens: number;
    completion_tokens: number;
    total_tokens: number;
    reasoning_tokens?: number;
  };
}

export async function callGPT5(
  apiKey: string,
  input: string,
  options: {
    model?: string;
    instructions?: string;
    reasoning_effort?: 'low' | 'medium' | 'high';
  } = {}
): Promise<{ content: string; usage?: any }> {
  const messages: GPT5Message[] = [];
  
  if (options.instructions) {
    messages.push({
      role: 'developer',
      content: options.instructions
    });
  }
  
  messages.push({
    role: 'user',
    content: input
  });

  const requestBody: GPT5Request = {
    model: options.model || 'gpt-5',
    messages,
    ...(options.reasoning_effort && { reasoning_effort: options.reasoning_effort })
  };

  console.error('Making GPT-5 API request:', JSON.stringify(requestBody, null, 2));

  const response = await fetch('https://api.openai.com/v1/chat/completions', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${apiKey}`,
    },
    body: JSON.stringify(requestBody)
  });

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(`GPT-5 API error: ${response.status} ${response.statusText} - ${errorText}`);
  }

  const data = await response.json() as GPT5Response;
  console.error('GPT-5 API response:', JSON.stringify(data, null, 2));

  const content = data.choices?.[0]?.message?.content || 'No response content';
  
  return {
    content,
    usage: data.usage
  };
}

export async function callGPT5WithMessages(
  apiKey: string,
  messages: GPT5Message[],
  options: {
    model?: string;
    instructions?: string;
    reasoning_effort?: 'low' | 'medium' | 'high';
  } = {}
): Promise<{ content: string; usage?: any }> {
  const allMessages: GPT5Message[] = [];
  
  if (options.instructions) {
    allMessages.push({
      role: 'developer',
      content: options.instructions
    });
  }
  
  allMessages.push(...messages);

  const requestBody: GPT5Request = {
    model: options.model || 'gpt-5',
    messages: allMessages,
    ...(options.reasoning_effort && { reasoning_effort: options.reasoning_effort })
  };

  console.error('Making GPT-5 API request with messages:', JSON.stringify(requestBody, null, 2));

  const response = await fetch('https://api.openai.com/v1/chat/completions', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${apiKey}`,
    },
    body: JSON.stringify(requestBody)
  });

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(`GPT-5 API error: ${response.status} ${response.statusText} - ${errorText}`);
  }

  const data = await response.json() as GPT5Response;
  console.error('GPT-5 API response:', JSON.stringify(data, null, 2));

  const content = data.choices?.[0]?.message?.content || 'No response content';
  
  return {
    content,
    usage: data.usage
  };
}
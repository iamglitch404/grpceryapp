import { NextResponse } from 'next/server';

export async function POST(request: Request) {
  try {
    const { messages } = await request.json();

    if (!messages || !Array.isArray(messages)) {
      return NextResponse.json(
        { error: 'Invalid messages format' },
        { status: 400 }
      );
    }

    const apiKey = process.env.MISTRAL_API_KEY;

    if (!apiKey) {
      console.error('Mistral API Key is missing');
      return NextResponse.json(
        { error: 'AI Service is currently unavailable (Missing API Key)' },
        { status: 500 }
      );
    }

    const response = await fetch('https://api.mistral.ai/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Accept: 'application/json',
        Authorization: `Bearer ${apiKey}`,
      },
      body: JSON.stringify({
        model: 'mistral-small-latest',
        messages: messages,
        temperature: 0.7,
      }),
    });

    if (!response.ok) {
      const errorData = await response.text();
      console.error('Mistral API Error:', response.status, errorData);
      return NextResponse.json(
        { error: 'Failed to communicate with AI provider' },
        { status: response.status }
      );
    }

    const data = await response.json();
    
    // We only need the text content to send back to the mobile app
    const content = data.choices?.[0]?.message?.content;
    
    if (!content) {
      return NextResponse.json(
        { error: 'Invalid response format from AI provider' },
        { status: 500 }
      );
    }

    return NextResponse.json({ text: content });
  } catch (error) {
    console.error('Chat API Error:', error);
    return NextResponse.json(
      { error: 'Internal Server Error' },
      { status: 500 }
    );
  }
}

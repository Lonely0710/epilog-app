import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req: Request) => {
    // Handle CORS preflight request
    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: corsHeaders })
    }

    try {
        const { path, query, method = 'GET', body } = await req.json()

        // TMDb API Base URL
        const TMDB_BASE_URL = 'https://api.themoviedb.org/3' // We can primarily use v3 endpoints but auth with v4 token

        // Construct the full URL
        let targetUrl = `${TMDB_BASE_URL}${path}`

        // Append query parameters
        if (query) {
            const searchParams = new URLSearchParams(query)
            targetUrl += `?${searchParams.toString()}`
        }

        console.log(`Forwarding request to: ${targetUrl}`)

        const tmdbToken = Deno.env.get('TMDB_ACCESS_TOKEN')
        if (!tmdbToken) {
            throw new Error('TMDB_ACCESS_TOKEN is not set in Edge Function secrets.')
        }

        // Make request to TMDb
        const response = await fetch(targetUrl, {
            method: method,
            headers: {
                'Authorization': `Bearer ${tmdbToken}`,
                'Content-Type': 'application/json',
                'Accept': 'application/json',
            },
            body: body ? JSON.stringify(body) : undefined,
        })

        const data = await response.json()

        return new Response(JSON.stringify(data), {
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            status: response.status,
        })

    } catch (error: any) {
        return new Response(JSON.stringify({ error: error.message }), {
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            status: 400,
        })
    }
})

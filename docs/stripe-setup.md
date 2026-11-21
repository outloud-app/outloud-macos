# Stripe setup while Outloud is in development

The account is intended for a UK business receiving GBP payouts. Customer pricing is currently planned in USD.

## Public business description

We develop Outloud, a Mac application that helps software developers research their audience and create marketing content. We plan to charge an annual software subscription and sell prepaid credits for AI-powered content generation.

## No website yet

The business website field in the live activation form requires a public URL. The supplied form explicitly permits a business social media profile or mobile app URL as alternatives. A social profile must genuinely represent this business and explain what it offers.

If none exists, leave live activation unfinished. Cancel the business-details edit, close Activate Payments, and continue developing in a sandbox/test environment.

A public product page should clearly describe Outloud and its development status, identify the business operating it, explain planned subscription/credit pricing, and provide support contact details. Complete applicable customer terms, privacy, cancellation and refund information before taking live payments. A public page does not guarantee Stripe approval.

Do not enter an unrelated website or invented URL.

## Payment integration plan

- Annual Outloud access: planned $129.99/year.
- Separate prepaid generation credits: planned $10–$1,000 per purchase.
- Credit balance is a product entitlement for Outloud services, not a withdrawable cash deposit.
- Hosted Stripe Checkout, customer portal and verified webhooks.
- Secret keys stay on the FastAPI server; the Mac application never embeds them.
- Sandbox testing can proceed before live activation is completed.

References:

- https://docs.stripe.com/get-started/account/set-up
- https://support.stripe.com/questions/do-i-have-to-have-a-business-website-to-sign-up-for-stripe?locale=en-GB

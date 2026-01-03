---
inclusion: fileMatch
fileMatchPattern: "repos/frontend/**"
---

# Core Microservices Frontend - Project Guidelines

## Project Context

This is an enterprise-grade React + TypeScript + Vite frontend demonstrating modular architecture patterns. The project showcases scalable, maintainable web applications with domain-driven design.

**Tech Stack**: React 18+, TypeScript, Vite, React Router v6+, Axios, React Query, React Bootstrap
**Backend**: Java Spring Boot microservices at https://github.com/CoreWebMicroservices/corems-project

## Architecture Principles

### Modular & Composable Design

1. **Standalone Modules** (`/user/`, `/communication/`, etc.)
   - Completely independent business logic components
   - No routing configuration in modules
   - No hardcoded dependencies between modules
   - Structure: `component/`, `store/`, `model/`, `config.ts`

2. **App-Level Composition** (`/app/`)
   - Composes modules into complete pages
   - All routing in `/app/router/AppRoutes.tsx`
   - Route paths in `/app/router/routes.ts`
   - Manages cross-module communication

3. **Configurable Common Components** (`/common/`)
   - Accept configuration parameters
   - No hardcoded app-specific logic
   - Reusable across different applications

### Import Rules
- **Always use global imports**: `@/app/layout/AppLayout` (never relative imports)
- **Centralized routes**: Import from `@/app/router/routes` not hardcoded paths
- **No cross-module imports**: Modules don't directly import from other modules

## Coding Standards

### General
- Functional components with React Hooks
- Type everything (props, hooks, state)
- Avoid large monolithic components
- Use ESLint and Prettier

### State Management
- **Global State (Hookstate)**: Truly global data (auth user, theme, shared entities)
- **Local State**: Component-specific data, especially DataTables and lists
- Avoid storing list data in global stores (prevents state pollution across tabs)
- Use `createDataTableActions` and `getInitialDataTableQueryParams`
- **React Query**: Server state caching where appropriate

### API Layer
- Use centralized `axiosInstance` from `common/utils/CoreMsApi.ts`
- JWT tokens stored in `localStorage`
- React Query for requests, caching, and invalidation

### Authentication
- Support email/password and OAuth2 (Google, GitHub)
- Configurable `AuthGuards` for route protection
- SUPER_ADMIN has access to all endpoints
- Auth state in `user/store/AuthState.ts`

### API Response Handling

**Return Types:**
- Use `CoreMsApiResonse<T>` for all API operations (provides `result`, `response`, `errors`)
- Only use `ApiSuccessfulResponse` for simple operations without detailed error context

**State Management Pattern:**
```typescript
// Store function (pure API)
export async function getAllUsers(queryParams: DataTableQueryParams): Promise<CoreMsApiResonse<UsersPagedResponse>> {
    const params = buildUrlSearchParams(queryParams);
    return await userMsApi.apiRequest<UsersPagedResponse>(
        HttpMethod.GET,
        `/api/users?${params.toString()}`
    );
}

// Component (local state)
const [users, setUsers] = useState<User[]>([]);
const result = await getAllUsers(queryParams);
if (result.result && result.response) {
    setUsers(result.response.items);
}
```

**Error Handling - Use MessageHandler:**
```typescript
import { useMessageState } from "@/common/utils/MessageHandler";

const { success, error, handleResponse } = useMessageState();
const result = await someApiCall(data);
handleResponse(
    result,
    "Failed to complete operation.",
    "Operation completed successfully."
);
```

**Key Principles:**
- No try-catch blocks in state functions (handled in `userMsApi.apiRequest`)
- Local state for lists (avoid global state pollution)
- Direct return of API responses
- Use MessageHandler for consistent error/success display

### UI/UX
- Use React Bootstrap for all UI components
- Consistent dark/light theme handling
- Display errors with `ApiResponseAlert` components

### Naming Conventions
- Folders: lowercase with hyphens (`user-profile/`)
- Components: PascalCase (`UserCard.tsx`)
- Hooks: useCamelCase (`useAuth.ts`)

## Backend Integration

**Microservices:**
- `user-ms`: Authentication, user profiles, roles (`/api/auth/*`, `/api/user/*`)
- `communication-ms`: Email, SMS, notifications (`/api/communication/*`)

**API Specs**: Located in each `-api` module's `resources/` folder
**Auth**: JWT tokens for all services
**Database**: PostgreSQL

## Environment

```bash
VITE_API_URL=https://api.corems.local
```

## Git Commits
- Keep commit messages minimal and concise
- Use conventional commit format: `feat:`, `fix:`, `refactor:`, etc.
- Focus on what changed, not implementation details

## When Writing Code

1. Follow modular architecture - components in module folders, routes in `/app/router/`
2. Use centralized routes from `@/app/router/routes`
3. Type everything
4. Use React Bootstrap components
5. Use CoreMsApi patterns for API calls
6. Make components configurable with props
7. Always display errors with ApiResponseAlert
8. Use environment variables for API URL
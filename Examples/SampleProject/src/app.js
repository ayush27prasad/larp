const greet = (name) => `Hello, ${name}`;

export function run(names) {
  return names.map(greet);
}

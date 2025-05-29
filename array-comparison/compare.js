function parseArray(str) {
  if (!str.trim()) return [];

  try {
    // Try to parse as JSON array
    const arr = JSON.parse(str);
    if (Array.isArray(arr)) {
      return arr;
    }
    throw new Error("Input must be a valid JSON array");
  } catch (e) {
    // If JSON parsing fails, try comma-separated values
    try {
      return str.split(",").map((item) => {
        const trimmed = item.trim();
        // Try to parse numbers
        if (!isNaN(trimmed)) {
          return Number(trimmed);
        }
        // Try to parse booleans
        if (trimmed.toLowerCase() === "true") return true;
        if (trimmed.toLowerCase() === "false") return false;
        // Return as string
        return trimmed;
      });
    } catch (e) {
      throw new Error(
        "Invalid input format. Please enter a valid JSON array or comma-separated values."
      );
    }
  }
}

function validateInput(textarea) {
  const value = textarea.value.trim();
  if (!value) {
    textarea.classList.remove("json-error");
    return true;
  }

  try {
    JSON.parse(value);
    textarea.classList.remove("json-error");
    return true;
  } catch (e) {
    textarea.classList.add("json-error");
    return false;
  }
}

function getArrayName(textarea) {
  const arrayId = textarea.id.replace("array", "");
  const nameInput = document.querySelector(
    `.array-name[data-array-id="${arrayId}"]`
  );
  return nameInput ? nameInput.value : `Array ${arrayId}`;
}

function addArrayInput() {
  const container = document.getElementById("arraysContainer");
  const arrayCount = container.querySelectorAll(".array-input-group").length;
  const newArrayNum = arrayCount + 1;

  const newGroup = document.createElement("div");
  newGroup.className = "array-input-group";
  newGroup.innerHTML = `
    <div class="array-col">
      <div class="array-header">
        <div class="array-title">
          <input type="text" value="Array ${newArrayNum}" class="array-name" data-array-id="${newArrayNum}" oninput="validateAndCompare()">
        </div>
        <button class="remove-button" onclick="removeArrayInput(this)">Remove</button>
      </div>
      <textarea id="array${newArrayNum}" placeholder="Enter comma-separated values or JSON array" oninput="validateAndCompare()"></textarea>
    </div>
  `;

  container.appendChild(newGroup);
}

function removeArrayInput(button) {
  const group = button.closest(".array-input-group");
  group.remove();
  // Renumber remaining arrays
  const containers = document.querySelectorAll(".array-input-group");
  containers.forEach((container, index) => {
    const input = container.querySelector(".array-name");
    const textarea = container.querySelector("textarea");
    const newNum = index + 1;
    input.value = `Array ${newNum}`;
    input.setAttribute("data-array-id", newNum);
    textarea.id = `array${newNum}`;
  });
  validateAndCompare();
}

function validateAndCompare() {
  const textareas = document.querySelectorAll("textarea");
  let hasError = false;

  textareas.forEach((textarea) => {
    if (!validateInput(textarea)) {
      hasError = true;
    }
  });

  if (!hasError) {
    compareArrays();
  }
}

function compareArrays() {
  let errorMsg = "";
  window.lastParseError = null;

  // Get all array inputs
  const arrayInputs = document.querySelectorAll("textarea");
  const arrays = [];
  const arrayNames = new Map();

  arrayInputs.forEach((input, index) => {
    try {
      const name = getArrayName(input);
      arrayNames.set(index, name);
      arrays.push(parseArray(input.value));
    } catch (e) {
      errorMsg = `<div class="error-message">Error parsing input: ${e.message}</div>`;
    }
  });

  // Calculate all possible combinations
  const results = [];
  for (let i = 0; i < arrays.length; i++) {
    for (let j = i + 1; j < arrays.length; j++) {
      const set1 = new Set(arrays[i]);
      const set2 = new Set(arrays[j]);

      const onlyIn1 = arrays[i].filter((x) => !set2.has(x));
      const onlyIn2 = arrays[j].filter((x) => !set1.has(x));
      const intersection = arrays[i].filter((x) => set2.has(x));

      results.push({
        array1: arrayNames.get(i),
        array2: arrayNames.get(j),
        onlyIn1,
        onlyIn2,
        intersection,
      });
    }
  }

  // Generate HTML for results
  let html = errorMsg;
  if (results.length > 0) {
    html += "<h3>Comparison Results</h3>";
    results.forEach((result) => {
      html += `
        <div class="diff">
          <span class="diff-header">Comparing ${result.array1} and ${
        result.array2
      }</span>
          <div class="diff-content">
            <div class="diff-section">
              <h4>Common Elements</h4>
              <ul class="diff-list">
                ${
                  result.intersection.length
                    ? result.intersection
                        .map((item) => `<li>${item}</li>`)
                        .join("")
                    : "<li>None</li>"
                }
              </ul>
            </div>
            <div class="diff-section">
              <h4>Only in ${result.array1}</h4>
              <ul class="diff-list">
                ${
                  result.onlyIn1.length
                    ? result.onlyIn1.map((item) => `<li>${item}</li>`).join("")
                    : "<li>None</li>"
                }
              </ul>
            </div>
            <div class="diff-section">
              <h4>Only in ${result.array2}</h4>
              <ul class="diff-list">
                ${
                  result.onlyIn2.length
                    ? result.onlyIn2.map((item) => `<li>${item}</li>`).join("")
                    : "<li>None</li>"
                }
              </ul>
            </div>
          </div>
        </div>
      `;
    });
  } else {
    html += '<div class="diff">Please add at least two arrays to compare</div>';
  }

  document.getElementById("result").innerHTML = html;
}

// Initialize the comparison
document.addEventListener("DOMContentLoaded", () => {
  // Add input event listeners to existing array name inputs
  document.querySelectorAll(".array-name").forEach((input) => {
    input.addEventListener("input", validateAndCompare);
  });
  validateAndCompare();
});

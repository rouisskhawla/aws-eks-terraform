def test_create_task(client):
    response = client.post(
        "/tasks/",
        json={"title": "Write tests", "description": "for the task API"},
    )
    assert response.status_code == 201
    data = response.json()
    assert data["title"] == "Write tests"
    assert data["description"] == "for the task API"
    assert data["completed"] is False
    assert "id" in data
    assert data["created_at"] is not None


def test_create_task_requires_title(client):
    response = client.post("/tasks/", json={"description": "no title given"})
    assert response.status_code == 422


def test_list_tasks_empty(client):
    response = client.get("/tasks/")
    assert response.status_code == 200
    assert response.json() == []


def test_list_tasks_returns_created_tasks(client):
    client.post("/tasks/", json={"title": "Task A"})
    client.post("/tasks/", json={"title": "Task B"})

    response = client.get("/tasks/")
    assert response.status_code == 200
    titles = [t["title"] for t in response.json()]
    assert titles == ["Task A", "Task B"]


def test_get_task_by_id(client):
    created = client.post("/tasks/", json={"title": "Find me"}).json()

    response = client.get(f"/tasks/{created['id']}")
    assert response.status_code == 200
    assert response.json()["title"] == "Find me"


def test_get_task_not_found(client):
    response = client.get("/tasks/9999")
    assert response.status_code == 404
    assert response.json()["detail"] == "Task not found"


def test_update_task_partial(client):
    created = client.post("/tasks/", json={"title": "Original", "completed": False}).json()

    response = client.patch(f"/tasks/{created['id']}", json={"completed": True})
    assert response.status_code == 200
    data = response.json()
    assert data["completed"] is True
    # title should be untouched by a partial update
    assert data["title"] == "Original"


def test_update_task_not_found(client):
    response = client.patch("/tasks/9999", json={"completed": True})
    assert response.status_code == 404


def test_delete_task(client):
    created = client.post("/tasks/", json={"title": "Delete me"}).json()

    response = client.delete(f"/tasks/{created['id']}")
    assert response.status_code == 204

    # confirm it's actually gone
    response = client.get(f"/tasks/{created['id']}")
    assert response.status_code == 404


def test_delete_task_not_found(client):
    response = client.delete("/tasks/9999")
    assert response.status_code == 404
